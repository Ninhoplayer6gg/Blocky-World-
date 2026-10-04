# Assets: onde colocar e como registrar

Os modelos, texturas, ícones e animações definitivos são produzidos fora do
projeto. Este guia diz onde cada arquivo vai e como ligá-lo ao jogo. **Nenhum
código precisa mudar** para trocar um placeholder pelo asset real.

## Como funciona

1. O conteúdo (JSON) referencia assets por **id**: `"texture":
   "blockyworld:blocks/stone"`.
2. O `ResourceManager` transforma o id em caminho:
   `<pack do namespace>/<tipo>/<caminho>.<extensão>`.
3. Se o arquivo existe, é usado. Se não, um placeholder gerado entra no lugar
   e o asset é anotado no relatório.
4. `/assets` (console) lista tudo que ainda é placeholder e o **caminho exato
   esperado** para cada arquivo. `/reload` aplica arquivos novos sem reiniciar.

| Tipo | Pasta | Extensões |
|------|-------|-----------|
| Texturas de bloco | `textures/blocks/` | `.png` |
| Ícones de item | `textures/items/` | `.png` |
| Modelos | `models/` (ex. `models/entities/`) | `.glb` (preferido), `.gltf`, `.tscn` |
| Animações | dentro do `.glb` (AnimationPlayer) | — |
| Sons | `sounds/` | `.ogg` (reservado) |

Para o conteúdo base, `<pack>` é `packs/blockyworld/`. Para um mod, a pasta do
mod.

## Texturas de bloco

- **PNG, quadrado, potência de 2.** Padrão 16×16. Todas as texturas de bloco
  compartilham um tamanho: o jogo usa o maior PNG encontrado e redimensiona os
  outros (com aviso no log). Para trocar a resolução do jogo inteiro, entregue
  todas no mesmo tamanho (ex. 32×32).
- Filtro *nearest* + mipmaps (pixel art nítida de perto, sem cintilar longe).
- Transparência: só em blocos `"render": "cutout"` (alfa < 0,5 é recortado).
- Faces diferentes: `"textures": {"top": ..., "side": ..., "bottom": ...}`.

Arquivos esperados pelo conteúdo base hoje (todos ainda placeholders):

```
packs/blockyworld/textures/blocks/
  stone.png  rough_stone.png  dirt.png  grass_top.png  grass_side.png
  sand.png  sandstone_top.png  sandstone_side.png  log_top.png  log_side.png
  planks.png  leaves.png  glass.png  bricks.png  cactus_top.png
  cactus_side.png  baserock.png  lab_tile.png  lab_tile_dark.png
```

`mods/example_mod/textures/` já contém PNGs reais (gerados por
`tools/generate_example_textures.gd`) e prova o caminho completo.

## Ícones de item

`"icon": "example:items/ruby"` → `textures/items/ruby.png`. Recomendado 16×16
ou 32×32. Itens de bloco sem `icon` usam um cubo isométrico montado das
texturas do bloco; outros itens sem ícone usam um losango colorido.

## Modelos de personagem e criaturas

Formato: **glTF 2.0 binário (`.glb`)**, com malha, esqueleto e animações no
mesmo arquivo.

Convenções:

| Item | Convenção |
|------|-----------|
| Escala | 1 unidade = 1 bloco = 1 metro. Jogador ≈ 1,8 de altura |
| Origem | nos pés, centralizada |
| Frente | **+Z** (padrão glTF). A entidade gira para o modelo olhar para +Z na direção do movimento |
| Pivôs | articulações nos ossos; personagens blocky podem ter malha rígida por osso |
| Texturas | embutidas no `.glb` ou PNG ao lado; filtro nearest recomendado para pixel art |

Registro (`content/models/<nome>.json`):

```json
{
  "id": "blockyworld:player",
  "scene": "blockyworld:entities/player",
  "attachment_bones": {
    "head": "Head", "face": "Head", "chest": "Chest", "back": "Chest",
    "left_hand": "Hand.L", "right_hand": "Hand.R", "waist": "Hips", "feet": "Root"
  },
  "animations": {"idle": "Idle", "walk": "Walk", "run": "Run", "jump": "Jump", "fall": "Fall"}
}
```

- `scene` → `packs/blockyworld/models/entities/player.glb`.
- `attachment_bones`: ponto lógico → nome do osso no `Skeleton3D`. Cada ponto
  vira um `BoneAttachment3D`, então itens presos (armas, cabelos, mochilas,
  acessórios) acompanham as animações. Pontos sem osso viram marcadores em
  posições padrão. Osso inexistente gera aviso.
- `animations`: nome lógico pedido pelo jogo → nome do clipe no
  `AnimationPlayer`. Clipes ausentes são simplesmente não tocados.

Pontos de attachment: `head`, `face`, `chest`, `back`, `left_hand`,
`right_hand`, `waist`, `feet`. Animações pedidas hoje: `idle`, `walk`, `run`,
`jump`, `fall`.

Entidade → modelo: `"model": "blockyworld:player"` no JSON da entidade.

### Arquivos em res:// vs. fora do projeto

- Dentro do projeto (`packs/`, `res://mods/`), a Godot importa o `.glb`
  (configurações de importação no editor) e o jogo usa a cena importada.
- Em `user://mods/` ou na pasta do executável, o `.glb` é carregado em runtime
  pelo `GLTFDocument` — funciona em builds exportados, sem editor.

## Placeholders

Todos são gerados em `rendering/placeholder_factory.gd` (um único lugar):

- blocos: cor sólida com ruído e borda escura;
- blocos de mod ausente: xadrez magenta/preto;
- itens: losango colorido;
- personagens: humanoide de caixas (`humanoid`) ou caixa (`box`), com os
  mesmos attachment points de um modelo real.

## Resource packs (planejado)

O `ResourceManager` já consulta resource packs antes do dono do namespace
(`<pack>/<namespace>/textures/...`); a UI para escolher packs chega depois.
Como todo acesso passa por ids, texturas, modelos, sons e UI podem ser
substituídos sem mudar código.

## Export (builds)

Para exportar, inclua arquivos não-recurso no preset: **Resources → Filters to
export non-resource files**: `*.json`. PNG e GLB em `res://` são exportados
como recursos importados automaticamente.
