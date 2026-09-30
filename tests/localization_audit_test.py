import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import validate_localization as VALIDATOR


class LocalizationAuditTest(unittest.TestCase):
    def _project(self, source: str, catalog: str) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / "localization").mkdir()
        (root / "scenes").mkdir()
        (root / "localization" / "en.csv").write_text(catalog, encoding="utf-8")
        (root / "scenes" / "player_text.gd").write_text(source, encoding="utf-8")
        return root

    def test_complete_source_keys_and_interpolation_report_full_coverage(self):
        root = self._project(
            'Localization.text("UI_START")\nLocalization.format("UI_COUNT", [count])\n',
            'keys,en\nUI_START,Start Run\nUI_COUNT,"You have %d choices"\n',
        )

        report = VALIDATOR.audit(root)

        self.assertTrue(report.passed, report.render())
        self.assertEqual(report.coverage, (2, 2))
        self.assertEqual(report.unresolved, [])

    def test_missing_key_fails_extraction_validation(self):
        root = self._project(
            'Localization.text("UI_MISSING")\n',
            'keys,en\nUI_START,Start Run\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("UI_MISSING", " ".join(report.unresolved))

    def test_unresolved_or_invalid_interpolation_fails_validation(self):
        root = self._project(
            'Localization.text("UI_COUNT")\nLocalization.format("UI_BROKEN", [count])\n',
            'keys,en\nUI_COUNT,"You have %d choices"\nUI_BROKEN,"You have %q choices"\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        structural_errors = " ".join(report.structural_errors)
        self.assertIn("UI_COUNT", structural_errors)
        self.assertIn("UI_BROKEN", structural_errors)

    def test_dynamic_content_ids_require_lowercase_stable_keys(self):
        root = self._project(
            'Localization.content_text("base.character.missing")\n',
            'keys,en\nUI_START,Start Run\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("base.character.missing", " ".join(report.unresolved))

    def test_direct_player_facing_section_heading_fails_extraction(self):
        root = self._project(
            '_add_section_heading(overview, "Unkeyed label")\n',
            'keys,en\nUI_START,Start Run\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("visible UI text", " ".join(report.structural_errors))

    def test_direct_player_facing_feedback_fails_extraction(self):
        root = self._project('state.feedback = "Unkeyed status"\n', 'keys,en\n')

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("player-facing feedback", " ".join(report.structural_errors))

    def test_direct_ui_text_assignment_fails_extraction(self):
        root = self._project('button.text = "Unkeyed button"\n', 'keys,en\n')

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("visible UI assignment", " ".join(report.structural_errors))

    def test_generated_encounter_variant_ids_are_extracted(self):
        root = self._project(
            'const ENCOUNTER_IDS := ["base.encounter.generated"]\n'
            'func register():\n\t_encounter_variants(ENCOUNTER_IDS[index], "base.enemy.test", "NORMAL")\n',
            'keys,en\nbase.encounter.generated,Encounter\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        unresolved = " ".join(report.unresolved)
        self.assertIn("base.encounter.generated.a", unresolved)
        self.assertIn("base.encounter.generated.b", unresolved)

    def test_dynamic_word_inventory_requires_source_entries(self):
        root = self._project(
            'Localization.word_text("UNLISTED")\n',
            'keys,en\nUI_START,Start Run\n',
        )
        helper = root / "src" / "presentation" / "localization" / "localization.gd"
        helper.parent.mkdir(parents=True)
        helper.write_text('static func required_word_values():\n\treturn ["UNLISTED"]\n', encoding="utf-8")

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("WORD_UNLISTED", " ".join(report.unresolved))

    def test_choice_and_milestone_words_are_extracted(self):
        root = self._project('Localization.word_text("leave")\n', 'keys,en\n')
        catalogs = root / "src" / "content" / "catalogs"
        catalogs.mkdir(parents=True)
        (catalogs / "events.gd").write_text(
            '{"choice_id": "leave", "alternatives": [{"alternative_id": "pay_now"}]}\n',
            encoding="utf-8",
        )
        run_domain = root / "src" / "domain" / "run"
        run_domain.mkdir(parents=True)
        (run_domain / "run_domain.gd").write_text(
            '_record_run_milestone("contract_chosen")\n'
            '_record_run_milestone("act_%d_boss_defeated" % act_index)\n',
            encoding="utf-8",
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        unresolved = " ".join(report.unresolved)
        self.assertIn("WORD_LEAVE", unresolved)
        self.assertIn("WORD_PAY_NOW", unresolved)
        self.assertIn("WORD_CONTRACT_CHOSEN", unresolved)
        self.assertIn("WORD_ACT_1_BOSS_DEFEATED", unresolved)
        self.assertIn("WORD_ACT_2_BOSS_DEFEATED", unresolved)

    def test_unused_invalid_format_token_fails_catalog_validation(self):
        root = self._project(
            'Localization.text("UI_START")\n',
            'keys,en\nUI_START,Start Run\nUI_UNUSED,"Broken %q format"\n',
        )

        report = VALIDATOR.audit(root)

        self.assertFalse(report.passed)
        self.assertIn("UI_UNUSED", " ".join(report.structural_errors))


if __name__ == "__main__":
    unittest.main()
