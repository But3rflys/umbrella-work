# Данные игры

В `%cheat_dir%/assets/data/` лежат данные Dota 2 в JSON, переведенные из KeyValues Valve:

| Файл | Что внутри |
| --- | --- |
| `npc_abilities.json` | способности героев и юнитов, корень `DOTAAbilities` |
| `items.json` | предметы, корень тоже `DOTAAbilities` |
| `neutral_items.json` | нейтральные предметы по тирам |
| `npc_heroes.json` | герои, корень `DOTAHeroes`: способности `Ability1..`, таланты `Ability10..`, атака, скорость, атрибуты |
| `npc_units.json` | юниты и крипы, корень `DOTAUnits` |

Это данные текущей версии игры. Бери из них, никогда не по памяти и не наугад:
- имена способностей и талантов для `NPC.GetAbility(npc, "centaur_hoof_stomp")`, `Ability.GetName`;
- имена предметов для `NPC.GetItem`, `NPC.HasItem` и имена героев и юнитов (`npc_dota_*`);
- `AbilityBehavior`, `AbilityCastPoint`, `AbilityChannelTime`, `AbilityCastRange`, кулдаун и ману по уровням;
- спецзначения из `AbilityValues`: это ключи для `Ability.GetLevelSpecialValueFor(ability, "radius")`.

Перед тем как вписать в код имя или число, посмотри его командой ниже. `luatool.exe check` сверяет с этими данными имена в `NPC.GetAbility`, `NPC.HasAbility`, `NPC.GetItem`, `NPC.HasItem`, ключи в `Ability.GetLevelSpecialValueFor` и любые строки вида `item_*` и `npc_dota_*`. Неизвестное имя дает `WARN` с подсказкой похожего. Исключение составляют кастомные режимы, например Dota 1x6: у них свои имена с окончанием `_custom`, в данных игры их нет, и check их пропускает. Такие имена не «исправляй» на обычные.

Файлы читает утилита, Node и Python не нужны:

```
luatool.exe data ability centaur_hoof_stomp
luatool.exe data item item_black_king_bar
luatool.exe data unit npc_dota_hero_centaur
luatool.exe data find hoof
```

Запускай из папки `scripts` чита или передай `--data <папка чита>`. Косметику (модели, звуки, частицы) утилита не выводит. Если имя не найдено, она предлагает похожие. Поля, которых нет в записи, берутся из базовой: `ability_base`, `npc_dota_hero_base`, `npc_dota_units_base`. Их можно посмотреть той же командой.

Пример вывода:

```
DATA ability centaur_hoof_stomp (npc_abilities.json)
AbilityBehavior: DOTA_ABILITY_BEHAVIOR_NO_TARGET | DOTA_ABILITY_BEHAVIOR_IMMEDIATE
AbilityCastPoint: 0
AbilityCooldown: 18 16 14 12
AbilityValues:
  radius: 325 (affected_by_aoe_increase 1)
  stun_duration: 1.6 1.8 2.0 2.2 (special_bonus_unique_centaur_2 0.8)
  windup_time: 0.5
```

Значение через пробел идет по уровням способности. В скобках указаны талант, который меняет значение, и прибавка от него. `dynamic_value true` значит, что игра считает значение на ходу, его берут в игре через `Ability.GetLevelSpecialValueFor`.
