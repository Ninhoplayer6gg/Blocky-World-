# Content Packs (JSON)

Content Packs registram conteúdo sem código. Ficam em `content/<tipo>/` dentro
de um mod (ou do pack base `packs/blockyworld/`). Cada arquivo `.json` contém
**um objeto** ou **uma lista de objetos**. Arquivos são lidos em ordem
alfabética.

Regras gerais:

- `id` é obrigatório. Pode ser completo (`example:ruby_block`) ou só o nome
  (`ruby_block`), que recebe o namespace do mod. O namespace precisa ser o do
  mod.
- Referências a outros conteúdos (blocos, itens, texturas) também aceitam o
  nome curto, que recebe o namespace do mod. Para referenciar outro mod ou o
  jogo base, use o id completo (`blockyworld:stone`).
- Campos desconhecidos geram um aviso (pega erros de digitação) e são
  ignorados. `comment` é sempre aceito.
- Cores: `"#rrggbb"`, `"#rrggbbaa"` ou `[r, g, b(, a)]` em 0..1.
- Erros são reportados com arquivo e motivo; a definição com erro é
  descartada, o resto do mod continua.

Tipos são carregados nesta ordem (em todos os mods): `attributes`, `blocks`,
`items`, `biomes`, `models`, `entities`.

## Blocos — `content/blocks/*.json`

```json
{
  "id": "example:ruby_block",
  "display_name": "Ruby Block",
  "texture": "example:blocks/ruby_block",
  "placeholder_color": "#b01a35",
  "hardness": 4,
  "solid": true,
  "transparent": false,
  "collision": true,
  "light": 3,
  "render": "opaque",
  "cull_same": true,
  "replaceable": false,
  "tags": ["example:gem_blocks"],
  "drops": [{"item": "example:ruby", "count": 4}],
  "item": {"max_stack": 32}
}
```

| Campo | Padrão | Descrição |
|-------|--------|-----------|
| `display_name` | derivado do id | nome visível |
| `texture` | — | textura de todas as faces (atalho para `textures.all`) |
| `textures` | — | por face: `all`, `side`, `top`, `bottom`, `east`, `west`, `south`, `north` (a mais específica vence) |
| `placeholder_color` | magenta | cor do placeholder enquanto o PNG não existe; aceita objeto por face como `textures` |
| `hardness` | 1 | tempo de quebra = `hardness × 0,3 s`; negativo = inquebrável |
| `solid` | true | ocupa o espaço |
| `transparent` | false | não oculta faces vizinhas |
| `collision` | = `solid` | gera colisão |
| `light` | 0 | 0–15, **armazenado para o motor de iluminação futuro (não renderizado na 0.1)** |
| `render` | `opaque` (`cutout` se transparente) | `opaque`, `cutout` (alpha recortado: folhas, vidro), `none` |
| `cull_same` | true | esconde faces entre dois blocos iguais (vidro com vidro) |
| `replaceable` | false | colocar um bloco por cima o substitui |
| `tags` | [] | ids namespaced livres |
| `drops` | o próprio bloco | lista de `{"item", "count"}` |
| `item` | gera item | `false` = sem item; objeto = campos do item gerado (`display_name`, `icon`, `max_stack`, `tags`, `properties`) |

Todo bloco ganha automaticamente um item com o **mesmo id** que o coloca.

## Itens — `content/items/*.json`

```json
{
  "id": "example:ruby",
  "display_name": "Ruby",
  "icon": "example:items/ruby",
  "placeholder_color": "#d0203f",
  "max_stack": 64,
  "places_block": null,
  "tags": ["example:gems"],
  "properties": {"example:value": 10}
}
```

| Campo | Padrão | Descrição |
|-------|--------|-----------|
| `icon` | — | textura do ícone; sem ícone, itens de bloco usam o cubo isométrico e os demais um losango gerado |
| `max_stack` | 64 | 1–9999 |
| `places_block` | — | id do bloco colocado ao usar o item |
| `properties` | {} | dados livres namespaced para sistemas futuros (ferramentas, comida...) |

`ItemStack` em runtime: `item_id`, `amount` e `metadata` (chaves namespaced,
valores compatíveis com JSON; pilhas só se juntam com metadata igual).

## Atributos — `content/attributes/*.json`

```json
{"id": "magic:mana", "display_name": "Mana", "default": 100, "min": 0, "max": 1000}
```

Atributos base: `blockyworld:max_health`, `blockyworld:movement_speed`,
`blockyworld:jump_strength`, `blockyworld:attack_damage`, `blockyworld:armor`.

## Biomas — `content/biomes/*.json`

```json
{
  "id": "blockyworld:desert",
  "temperature": 0.85,
  "humidity": 0.15,
  "surface_block": "sand",
  "subsurface_block": "sand",
  "subsurface_depth": 4,
  "stone_block": "sandstone",
  "height_offset": -1,
  "height_variation": 0.45,
  "features": [
    {"type": "blockyworld:column", "chance": 0.005, "block": "cactus", "min_height": 1, "max_height": 3}
  ]
}
```

O gerador padrão escolhe o bioma cujo ponto `(temperature, humidity)` (0..1)
está mais perto do clima local e mistura a altura entre biomas vizinhos.
Biomas de mods entram no mesmo mapa de clima automaticamente.

Features disponíveis (por coluna de superfície, `chance` = probabilidade):

| `type` | Parâmetros |
|--------|------------|
| `blockyworld:tree` | `log_block`, `leaves_block`, `min_height`, `max_height` |
| `blockyworld:column` | `block`, `min_height`, `max_height` |

Parâmetros `block` e `*_block` aceitam nomes curtos (namespace do mod).

## Modelos — `content/models/*.json`

```json
{
  "id": "blockyworld:player",
  "scene": "blockyworld:entities/player",
  "scale": 1.0,
  "placeholder": {"type": "humanoid", "colors": {"skin": "#d9ad8c", "body": "#3a7fb8", "legs": "#3b3f63"}},
  "attachment_bones": {"head": "Head", "right_hand": "Hand.R", "left_hand": "Hand.L", "chest": "Chest"},
  "animations": {"idle": "Idle", "walk": "Walk", "run": "Run", "jump": "Jump", "fall": "Fall"}
}
```

`scene` é um id de modelo (`<pack>/models/entities/player.glb`). Placeholder:
`humanoid` ou `box` (com `colors.body`). Ver [Assets.md](Assets.md).

## Entidades — `content/entities/*.json`

```json
{
  "id": "blockyworld:test_dummy",
  "display_name": "Test Dummy",
  "model": "blockyworld:test_dummy",
  "width": 0.6,
  "height": 1.8,
  "eye_height": 1.5,
  "attributes": {"blockyworld:max_health": 10, "blockyworld:movement_speed": 3.0},
  "components": [
    {"type": "blockyworld:movement", "modes": ["walk"]},
    {"type": "blockyworld:health", "remove_on_death": true},
    {"type": "blockyworld:wander", "speed_factor": 0.6}
  ],
  "tags": ["blockyworld:dev"]
}
```

Componentes disponíveis:

| `type` | Parâmetros |
|--------|------------|
| `blockyworld:movement` | `modes` (`walk`, `fly`), `gravity`, `ground_acceleration`, `air_acceleration`, `sprint_multiplier`, `terminal_velocity` |
| `blockyworld:health` | `remove_on_death` |
| `blockyworld:wander` | `speed_factor`, `min_idle`, `max_idle`, `max_walk` |

`type` sem namespace assume `blockyworld:`. Componentes, atributos ou modelos
desconhecidos são removidos com aviso. Teste com `/spawn <id>`.

## Recarregar

Edite um JSON ou PNG e digite `/reload` no console (ver
[Modding.md](Modding.md#hot-reload)).
