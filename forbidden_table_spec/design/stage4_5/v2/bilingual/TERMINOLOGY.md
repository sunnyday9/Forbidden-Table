# English / 简体中文 terminology

These are proposed player-facing names. Stable Domain IDs and the English source catalog remain authoritative; Chinese names do not rename entities or introduce Chinese Mahjong scoring rules.

| English | 简体中文 | Meaning / constraint |
|---|---|---|
| Forbidden Table | 禁忌牌桌 | Proposed localized display title; repository/product identity stays Forbidden Table. |
| Run | 旅程 | One existing Run. |
| Act | 幕 | Two Acts remain. |
| Character / Contract | 角色 / 契约 | Existing selection roster. |
| Reserve (Character) | 藏牌师 | Character `base.character.reserve`. |
| Sequence (Character) | 顺子师 | Character `base.character.sequence`. |
| Harbor reader | 港湾读者 | Existing unlock condition: Act 2 Normal Ending. |
| Hand / Reserve / Tile Pool | 手牌 / 备牌 / 牌池 | Distinct zones; Reserve is potential Yaku progress except where an existing Rule Breaker permits participation. |
| Discard / Exhaust | 弃牌区 / 耗尽区 | Distinct zones; never conflate them in help or details. |
| TileDefinition / TileInstance | 基础牌面 / 具体牌实例 | Player details use face + 副本编号. Duplicate instances remain separately reachable. |
| Characters / Dots / Bamboo | 万子 / 筒子 / 条子 | Names use 一万 / 一筒 / 一条 through 九. Tile image retains standard 萬. |
| East / South / West / North | 东风 / 南风 / 西风 / 北风 | Wind tiles. `HON:WEST` is West; `HON:W` is White dragon. |
| Red / Green / White dragon | 红中 / 发财 / 白板 | Standard honor names. Original image retains 發. |
| Pattern / Sequence / Triplet / Quad / Pair | 牌型 / 顺子 / 刻子 / 杠子 / 对子 | Pair cannot settle independently. Quad consumes four physical instances. |
| Complete Hand / Standard / Seven Pairs | 完整和牌 / 标准和牌 / 七对 | 4 Groups + Pair or seven distinct Pairs; physical count can increase with Quads. |
| Settlement / Partial Settlement | 结算 / 部分结算 | Game action; not a new Mahjong call. |
| Yaku / Mahjong Score | 役种 / 麻将分数 | Preserve the game's existing evaluations and score. No fan system added. |
| Pressure / Stability / Integrity | 压力 / 稳定度 / 完整度 | Integrity applies to each Reserve instance. |
| TP | TP | Keep existing abbreviation; full definition must use existing game help, never invent an expansion. |
| Gold / Refinement Token | 金币 / 精炼代币 | Keep currency identity and costs. Compact resource rail 精炼 means Refinement Tokens. |
| Relic / Technique / Core Technique | 遗物 / 技法 / 核心技法 | Existing build content. |
| Rule Breaker / Modifier / Contamination | 破规能力 / 修饰 / 污染 | Existing effects, not new systems. |
| Pool Bias / Refinement Debt / Open Ledger | 牌池偏向 / 精炼债务 / 开放账册 | Existing Contracts. |
| Reserve Sleeve / Reserve Ledger / Sequence Line | 藏牌袖套 / 备牌账册 / 顺子路线 | Existing Relic/Techniques. |
| Complete Hand Insurance / Settlement Seal / Settlement Chart | 和牌保险 / 结算印章 / 结算海图 | Existing Relics; effects unchanged. |
| Open Table / Draw Actions / Reserve Witness | 开放牌桌 / 额外摸牌 / 备牌见证 | Existing Rule Breakers; capacity values unchanged. |
| Shop / Workshop / Transform | 商店 / 工坊 / 变换 | Existing services and confirmation paths. |
| Run Summary / Build Story | 旅程总结 / 构筑纪事 | Existing summary information. |
| none recorded / not tracked | 无记录 / 未记录此项 | Recorded empty value versus unavailable historical field; never collapse these. |
| Normal / Fast / Instant | 标准 / 快速 / 瞬时 | Stable mode values remain Normal / Fast / Instant. Normal encounter = 普通战斗. |
| selected / focused / disabled | 已选择 / 有焦点 / 不可用 | Separate states; locked = 未解锁. |

Use Simplified Chinese sentence punctuation and concise action verbs. Preserve interpolation placeholders, literal percent signs, error codes, paths, IDs, and input glyphs. Dates and durations may be formatted per locale without changing values. Translated proper names are proposals for maintainer review.
