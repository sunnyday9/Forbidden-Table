#!/usr/bin/env python3
"""Validate Godot's keyed English source catalog and all literal key call sites."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path


KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_.-]*$")
FORMAT_RE = re.compile(r"%(?:[0-9]+\$)?([sdif])")
FORMAT_TOKEN_RE = re.compile(r"%(?:[0-9]+\$)?[sdif]|%%")
LITERAL_PERCENT_RE = re.compile(r"%%")
CALL_RE = re.compile(r'(?:Localization(?:CatalogScript)?|ContentTextCatalogScript)\.(text|format|template|canonical_text)\s*\(\s*"([^"]+)"')
CONTENT_PRESENTATION_IMPORT_RE = re.compile(r'["\']res://src/presentation/')
MESSAGE_PART_CALL_RE = re.compile(r'(?<![A-Za-z0-9_])_localized_message_part\s*\(\s*"([^"]+)"')
SCENE_KEY_RE = re.compile(r'^\s*text\s*=\s*"([A-Za-z][A-Za-z0-9_.-]*)"\s*$', re.MULTILINE)
DIRECT_UI_TEXT_CALL_RE = re.compile(r'_(?:add_section_heading|set_wrapped_label_text)\([^,]+,\s*"([^"]*)"')
DIRECT_UI_TEXT_ASSIGNMENT_RE = re.compile(r'\.(?:text|tooltip_text|placeholder_text)\s*=\s*"([^"]+)"')
DIRECT_FEEDBACK_RE = re.compile(r'state\.feedback\s*=\s*"([^"]+)"')
CONTENT_ID_RE = re.compile(r'"((?:base|alpha|prototype|run|phase2)\.[a-z0-9_]+(?:\.[a-z0-9_-]+)+)"')


@dataclass
class Reference:
    path: str
    key: str
    kind: str
    argument_count: int


@dataclass
class Report:
    references: list[Reference]
    keys: dict[str, str]
    unresolved: list[str]
    structural_errors: list[str]
    locale_keys: dict[str, str]

    @property
    def coverage(self) -> tuple[int, int]:
        unique_references = {reference.key for reference in self.references}
        return len(unique_references.intersection(self.keys)), len(unique_references)

    @property
    def passed(self) -> bool:
        return not self.unresolved and not self.structural_errors

    def render(self) -> str:
        covered, total = self.coverage
        percentage = 100 if total == 0 else round(covered * 100 / total)
        literal_keys = {reference.key for reference in self.references if reference.kind in {"text", "format", "template", "canonical_text", "message_part", "scene"}}
        content_ids = {reference.key for reference in self.references if reference.kind == "content_id"}
        dynamic_words = {reference.key for reference in self.references if reference.kind == "dynamic_word"}
        lines = [f"Localization source extraction: {covered}/{total} stable keys ({percentage}%)"]
        lines.append(f"Literal UI/content keys: {len(literal_keys)}; dynamic content-ID labels: {len(content_ids)}; dynamic word labels: {len(dynamic_words)}")
        lines.append(f"English source entries: {len(self.keys)}; unresolved items: {len(self.unresolved)}")
        locale_errors = sum("zh_CN.csv" in item for item in self.structural_errors)
        lines.append(f"Simplified Chinese entries: {len(self.locale_keys)}; locale audit errors: {locale_errors}")
        lines.extend(f"UNRESOLVED: {item}" for item in self.unresolved)
        lines.extend(f"INVALID: {item}" for item in self.structural_errors)
        return "\n".join(lines)


def _split_top_level_arguments(source: str) -> list[str]:
    arguments: list[str] = []
    start = 0
    depth = 0
    quote = ""
    escaped = False
    for index, character in enumerate(source):
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character in ('"', "'"):
            quote = character
        elif character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif character == "," and depth == 0:
            arguments.append(source[start:index].strip())
            start = index + 1
    tail = source[start:].strip()
    if tail:
        arguments.append(tail)
    return arguments


def _matching_call(source: str, call_start: int) -> tuple[int, list[str]] | None:
    open_paren = source.find("(", call_start)
    if open_paren < 0:
        return None
    depth = 1
    quote = ""
    escaped = False
    close_paren = -1
    for index in range(open_paren + 1, len(source)):
        character = source[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character in ('"', "'"):
            quote = character
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                close_paren = index
                break
    if close_paren < 0:
        return None
    return close_paren, _split_top_level_arguments(source[open_paren + 1 : close_paren])


def _template_argument_count(source: str, close_paren: int) -> int:
    tail = source[close_paren + 1 :]
    match = re.match(r"\s*%\s*", tail)
    if not match:
        return 0
    value_start = close_paren + 1 + match.end()
    if value_start >= len(source):
        return -1
    if source[value_start] != "[":
        return 1
    depth = 0
    quote = ""
    escaped = False
    for index in range(value_start, len(source)):
        character = source[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character in ('"', "'"):
            quote = character
        elif character == "[":
            depth += 1
        elif character == "]":
            depth -= 1
            if depth == 0:
                values = source[value_start + 1 : index].strip()
                return len(_split_top_level_arguments(values)) if values else 0
    return -1


def _call_argument_count(source: str, call_start: int, call_kind: str) -> int:
    if call_kind in {"text", "canonical_text"}:
        return 0
    call_info = _matching_call(source, call_start)
    if call_info is None:
        return -1
    close_paren, arguments = call_info
    if call_kind == "template":
        return _template_argument_count(source, close_paren)
    if call_kind == "message_part" and len(arguments) == 1:
        return 0
    if len(arguments) < 2 or not arguments[1].startswith("[") or not arguments[1].endswith("]"):
        return -1
    values = arguments[1][1:-1].strip()
    return len(_split_top_level_arguments(values)) if values else 0


def _parse_catalog(path: Path) -> tuple[dict[str, str], list[str]]:
    entries: dict[str, str] = {}
    errors: list[str] = []
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as source:
            reader = csv.DictReader(source)
            if reader.fieldnames != ["keys", "en"]:
                return {}, [f"{path}: expected exactly the columns 'keys,en'; got {reader.fieldnames!r}"]
            for row_number, row in enumerate(reader, start=2):
                key = (row.get("keys") or "").strip()
                value = row.get("en") or ""
                if not KEY_RE.fullmatch(key):
                    errors.append(f"{path}:{row_number}: invalid stable key {key!r}")
                if not value.strip():
                    errors.append(f"{path}:{row_number}: English source text for {key!r} is empty")
                if key in entries:
                    errors.append(f"{path}:{row_number}: duplicate key {key!r}")
                else:
                    entries[key] = value
    except (OSError, csv.Error) as error:
        return {}, [f"{path}: {error}"]
    return entries, errors


def _parse_locale_catalog(path: Path, locale_column: str) -> tuple[dict[str, str], list[str]]:
    entries: dict[str, str] = {}
    errors: list[str] = []
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as source:
            reader = csv.DictReader(source)
            if reader.fieldnames != ["keys", locale_column]:
                return {}, [f"{path}: expected exactly the columns 'keys,{locale_column}'; got {reader.fieldnames!r}"]
            for row_number, row in enumerate(reader, start=2):
                key = (row.get("keys") or "").strip()
                value = row.get(locale_column) or ""
                if not KEY_RE.fullmatch(key):
                    errors.append(f"{path}:{row_number}: invalid stable key {key!r}")
                if not value.strip():
                    errors.append(f"{path}:{row_number}: {locale_column} translation for {key!r} is empty")
                if key in entries:
                    errors.append(f"{path}:{row_number}: duplicate key {key!r}")
                else:
                    entries[key] = value
    except (OSError, csv.Error) as error:
        return {}, [f"{path}: {error}"]
    return entries, errors


def _check_format(key: str, template: str, argument_count: int, location: str, errors: list[str]) -> None:
    without_escaped_percents = LITERAL_PERCENT_RE.sub("", template)
    placeholders = FORMAT_RE.findall(without_escaped_percents)
    stripped_tokens = FORMAT_RE.sub("", without_escaped_percents)
    if "%" in stripped_tokens:
        errors.append(f"{location}: invalid format token in {key!r}: {template!r}")
    if len(placeholders) != argument_count:
        errors.append(
            f"{location}: {key!r} has {len(placeholders)} placeholder(s), "
            f"but its call supplies {argument_count} value(s)"
        )


def _check_format_syntax(key: str, template: str, location: str, errors: list[str]) -> None:
    without_escaped_percents = LITERAL_PERCENT_RE.sub("", template)
    stripped_tokens = FORMAT_RE.sub("", without_escaped_percents)
    if "%" in stripped_tokens:
        errors.append(f"{location}: invalid format token in {key!r}: {template!r}")


def _dynamic_content_ids(root: Path, source_paths: list[Path]) -> set[str]:
    identifiers: set[str] = set()
    for path in source_paths:
        source = path.read_text(encoding="utf-8")
        identifiers.update(CONTENT_ID_RE.findall(source))
        string_constants = dict(
            (name, value)
            for name, value in re.findall(r'const\s+([A-Z][A-Z0-9_]*)\s*:=\s*"([^"]+)"', source)
        )
        array_constants: dict[str, set[str]] = {}
        for name, body in re.findall(r"const\s+([A-Z][A-Z0-9_]*)\s*:=\s*\[(.*?)\]", source, re.S):
            array_constants[name] = set(CONTENT_ID_RE.findall(body))
        for constant in re.findall(r"_encounter_variants\(\s*([A-Z][A-Z0-9_]*)(?:\[[^\]]+\])?", source):
            bases = array_constants.get(constant, set())
            if not bases and constant in string_constants:
                bases = {string_constants[constant]}
            for base_id in bases:
                identifiers.update((f"{base_id}.a", f"{base_id}.b"))
    # Run Summary renders recorded Boss IDs through the same dynamic content
    # label path. Include its historical fixture because it is not registered
    # in the current catalog but can still reach player-facing summary text.
    summary_fixture = root / "tests" / "run_summary_test.gd"
    if summary_fixture.exists():
        identifiers.update(CONTENT_ID_RE.findall(summary_fixture.read_text(encoding="utf-8")))
    if (root / "src" / "content" / "catalogs" / "mini_act_map_catalog.gd").exists():
        node_parts = ["intro", "normal.left", "normal.right", "shop", "workshop", "event.left", "event.right", "normal.mid", "elite", "boss"]
        for prefix in ("base.map_node.", "base.map_node.act_two."):
            identifiers.update(prefix + part for part in node_parts)
        for suit in ("characters", "bamboo", "dots"):
            identifiers.update(f"base.tile.{suit}.{rank}" for rank in range(1, 10))
        identifiers.update(f"base.tile.honors.{name}" for name in ("east", "south", "west", "north", "red", "green", "white"))
        identifiers.add("base.tile.man.5")
    return identifiers


def _dynamic_word_values(root: Path) -> list[str]:
    path = root / "src" / "presentation" / "localization" / "localization.gd"
    values: set[str] = set()
    if path.exists():
        source = path.read_text(encoding="utf-8")
        inventory = re.search(r"static func required_word_values\(\).*?:\n(.*?)(?=\nstatic func |\Z)", source, re.S)
        if inventory is not None:
            values.update(re.findall(r'"([^"]+)"', inventory.group(1)))
    for catalog in sorted((root / "src" / "content" / "catalogs").glob("*.gd")):
        source = catalog.read_text(encoding="utf-8")
        values.update(re.findall(r'"(?:choice_id|alternative_id)"\s*:\s*"([^"]+)"', source))
    for domain_file in sorted((root / "src" / "domain" / "run").glob("*.gd")):
        source = domain_file.read_text(encoding="utf-8")
        values.update(re.findall(r'_record_run_milestone\("([^"]+)"\)', source))
        if '"act_%d_boss_defeated"' in source:
            values.update(("act_1_boss_defeated", "act_2_boss_defeated"))
    return sorted(values)


def audit(root: Path) -> Report:
    catalog_path = root / "localization" / "en.csv"
    keys, structural_errors = _parse_catalog(catalog_path)
    for key, template in keys.items():
        _check_format_syntax(key, template, str(catalog_path.relative_to(root)), structural_errors)
    chinese_path = root / "localization" / "zh_CN.csv"
    chinese_keys, chinese_errors = _parse_locale_catalog(chinese_path, "zh_CN")
    structural_errors.extend(chinese_errors)
    missing_chinese = sorted(set(keys) - set(chinese_keys))
    orphan_chinese = sorted(set(chinese_keys) - set(keys))
    structural_errors.extend(f"{chinese_path.relative_to(root)}: missing Chinese translation for {key}" for key in missing_chinese)
    structural_errors.extend(f"{chinese_path.relative_to(root)}: orphan Chinese key {key}" for key in orphan_chinese)
    content_paths = sorted((root / "src" / "content").rglob("*.gd"))
    for path in content_paths:
        source = path.read_text(encoding="utf-8")
        for match in CONTENT_PRESENTATION_IMPORT_RE.finditer(source):
            line_number = source.count("\n", 0, match.start()) + 1
            structural_errors.append(
                f"{path.relative_to(root)}:{line_number}: Content code must not depend on Presentation"
            )
    for key in sorted(set(keys).intersection(chinese_keys)):
        source_tokens = FORMAT_TOKEN_RE.findall(keys[key])
        translated_tokens = FORMAT_TOKEN_RE.findall(chinese_keys[key])
        if source_tokens != translated_tokens:
            structural_errors.append(
                f"{chinese_path.relative_to(root)}: {key!r} placeholder tokens differ from English: "
                f"{source_tokens!r} != {translated_tokens!r}"
            )
        _check_format_syntax(key, chinese_keys[key], str(chinese_path.relative_to(root)), structural_errors)
    references: list[Reference] = []
    unresolved: list[str] = []
    source_paths = sorted(
        [*root.glob("scenes/**/*.gd"), *root.glob("src/presentation/**/*.gd"), *content_paths]
    )
    for path in source_paths:
        source = path.read_text(encoding="utf-8")
        for match in DIRECT_UI_TEXT_CALL_RE.finditer(source):
            if not match.group(1):
                continue
            line_number = source.count("\n", 0, match.start()) + 1
            structural_errors.append(
                f"{path.relative_to(root)}:{line_number}: visible UI text {match.group(1)!r} must resolve through a localization key"
            )
        for match in DIRECT_UI_TEXT_ASSIGNMENT_RE.finditer(source):
            line_number = source.count("\n", 0, match.start()) + 1
            structural_errors.append(
                f"{path.relative_to(root)}:{line_number}: visible UI assignment {match.group(1)!r} must resolve through a localization key"
            )
        for match in DIRECT_FEEDBACK_RE.finditer(source):
            line_number = source.count("\n", 0, match.start()) + 1
            structural_errors.append(
                f"{path.relative_to(root)}:{line_number}: player-facing feedback {match.group(1)!r} must resolve through a localization key"
            )
        calls = [(match.group(1), match.group(2), match.start()) for match in CALL_RE.finditer(source)]
        calls.extend(("message_part", match.group(1), match.start()) for match in MESSAGE_PART_CALL_RE.finditer(source))
        for kind, key, call_start in sorted(calls, key=lambda call: call[2]):
            argument_count = _call_argument_count(source, call_start, kind)
            if argument_count < 0:
                structural_errors.append(f"{path.relative_to(root)}: malformed Localization.{kind} call for {key!r}")
                continue
            reference = Reference(str(path.relative_to(root)), key, kind, argument_count)
            references.append(reference)
            if key not in keys:
                unresolved.append(f"{reference.path}: missing key {key}")
                continue
            _check_format(key, keys[key], argument_count, reference.path, structural_errors)

    for content_id in sorted(_dynamic_content_ids(root, source_paths)):
        references.append(Reference("dynamic content ID inventory", content_id, "content_id", 0))
        if content_id not in keys:
            unresolved.append(f"dynamic content ID has no English source key: {content_id}")
        else:
            _check_format(content_id, keys[content_id], 0, "dynamic content ID inventory", structural_errors)

    for value in sorted(set(_dynamic_word_values(root))):
        normalized = value.strip().upper().replace(" ", "_").replace("-", "_")
        key = "WORD_" + normalized
        references.append(Reference("dynamic word inventory", key, "dynamic_word", 0))
        if key not in keys:
            unresolved.append(f"dynamic word has no English source key: {value!r} ({key})")
        else:
            _check_format(key, keys[key], 0, "dynamic word inventory", structural_errors)
    for path in sorted(root.glob("scenes/**/*.tscn")):
        source = path.read_text(encoding="utf-8")
        for match in SCENE_KEY_RE.finditer(source):
            key = match.group(1)
            references.append(Reference(str(path.relative_to(root)), key, "scene", 0))
            if key not in keys:
                unresolved.append(f"{path.relative_to(root)}: missing key {key}")
            else:
                _check_format(key, keys[key], 0, str(path.relative_to(root)), structural_errors)
    return Report(references, keys, unresolved, structural_errors, chinese_keys)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    arguments = parser.parse_args(argv)
    report = audit(arguments.root.resolve())
    print(report.render())
    return 0 if report.passed else 1


if __name__ == "__main__":
    sys.exit(main())
