# Arquitetura do Blocky World

Este documento explica como o motor está organizado, o fluxo de dados e as
decisões que importam para crescer o projeto (e os mods) por muito tempo.

## Princípios

1. **O jogo base é um mod.** `packs/blockyworld/` tem `mod.json` e Content
   Packs JSON como qualquer mod. Não existe caminho especial para o conteúdo
   vanilla: se um mod não consegue fazer algo, o jogo base também não faz por
   um atalho.
2. **Tudo que é registrável tem id namespaced** (`blockyworld:stone`,
   `example:ruby`). O nome visível nunca é usado como chave.
3. **Ciclo de vida controlado.** Conteúdo só entra nos registries numa fase
   específica do boot; depois eles são congelados.
4. **Dados separados de nós.** Blocos vivem em arrays por chunk; a cena só
   contém uma malha e uma colisão por *seção* de chunk. Nunca um Node por bloco.
5. **Threads só tocam cópias.** Jobs em background recebem snapshots e devolvem
   arrays; só a thread principal cria recursos da Godot.
6. **Erros visíveis.** Mod quebrado, JSON inválido, chunk corrompido ou mod
   ausente geram mensagens claras no log, no console e na UI, sem fechar o jogo
   e sem corromper dados.

## Mapa de módulos

| Pasta | Responsabilidade |
|-------|------------------|
| `core/` | `Game` (autoload), `ContentPipeline` (boot), `Registry` genérico, `EventBus`, `Log`, `GameConfig`, `GameInfo` (versões), `ResourceManager`, `Settings`, `InputActions`, `JobRunner` |
| `modding/` | `ModManifest` (mod.json), `ModLoader` (descoberta, validação, dependências, ordem), `ContentLoader` + `ContentParsers` (JSON → definições), `SemVer` |
| `blocks/`, `items/`, `inventory/`, `attributes/` | Definições, registries, `ItemStack`, `Inventory`, `AttributeSet` |
| `voxel/` | `ChunkData`, `VoxelCoords`, `ChunkSnapshot`, `ChunkMesher`, `MeshingContext`, `VoxelRaycast` |
| `world/` | `World` (API de blocos), `ChunkManager` (streaming), `ChunkNode`, geradores, biomas, `GameSession` |
| `entities/` | `Entity`, `EntityComponent`, componentes, `CharacterModel`, `EntityManager`, modelos |
| `player/`, `interaction/` | `Player` e `BlockInteraction` |
| `rendering/` | `BlockTextures` (Texture2DArray + materiais), shaders, `PlaceholderFactory`, ícones, ambiente |
| `save/` | `WorldSave`, `ChunkStorage`, `ChunkSerializer`, `SaveMigrations`, `SafeFile`, `SaveManager` |
| `debug/`, `ui/` | Console e comandos, overlay F3, menus, HUD |

## Boot (ciclo de carregamento)

`Game._ready()` → `ContentPipeline.run()` (ver `core/content_pipeline.gd`):

```
ENGINE_START
LOAD_CORE              tipos implementados em código (componentes, geradores,
                       features de terreno) — CoreRegistration
DISCOVER_MODS          res://packs (embutido), res://mods, user://mods,
                       <pasta do executável>/mods
VALIDATE_MODS          mod.json: campos, tipos, id, versão, api_version
RESOLVE_DEPENDENCIES   duplicados, namespace reservado, dependência ausente/
                       desativada/com erro/versão incompatível, ciclos;
                       ordem topológica (pack base primeiro, empates alfabéticos)
REGISTER_CONTENT       JSON por tipo, em todos os mods: attributes → blocks
                       (+ item do bloco) → items → biomes → models → entities
FINALIZE_REGISTRIES    valida referências cruzadas; congela registries
READY                  constrói texturas, materiais e tabelas de meshing
```

Depois de `FINALIZE`, `register()` retorna `ERR_LOCKED`. As únicas exceções
são explícitas e controladas:

- **placeholders de blocos de mods ausentes**, criados ao abrir um mundo
  (`BlockRegistry.create_missing_placeholder`), e
- **hot reload** (`/reload`), que roda o pipeline inteiro de novo num conjunto
  novo de registries e faz *merge*: definições existentes de blocos/itens são
  atualizadas no lugar (ids de runtime continuam válidos), novas são
  adicionadas no fim, e os demais registries são substituídos.

## Registries e ids

`Registry` guarda entradas por id e por ordem de registro (determinística).
`BlockRegistry` ainda atribui **runtime ids** compactos (inteiros, `air = 0`)
usados dentro dos arrays de chunk. Runtime ids valem só para a sessão; o disco
usa a *paleta do mundo* (ver [SaveFormat.md](SaveFormat.md)).

`ScriptTypeRegistry` mapeia ids para implementações em código
(`blockyworld:movement` → `MovementComponent`). O JSON referencia esses ids. A
API Lua futura registrará tipos aqui, sem mudar o formato do conteúdo.

## Mundo voxel

### Chunks

- Chunk = coluna `16 x 128 x 16` (`GameConfig.CHUNK_SIZE_*`).
- Dados: um `PackedInt32Array` plano, índice `x + z*16 + y*256`.
  128 KB por chunk; com distância 6 (~225 chunks com dados) ≈ 29 MB.
- A coluna é dividida em **seções de 16 de altura** para meshing: editar um
  bloco remalha só a seção dele (mais vizinhas na borda) e seções vazias são
  puladas (`section_counts`).

Por que coluna + seções e não cubos 16³ independentes: save/load e geração
ficam simples (uma coluna = um arquivo = um job), e o custo de edição continua
local. Se o mundo precisar de mais altura, aumentar `CHUNK_SIZE_Y` funciona; o
próximo passo seria armazenamento por seção com paleta (ver Roadmap).

### Geração

`WorldGenerator` é a base; geradores são registrados por id e escolhidos por
mundo (`world.json` → `generator`).

- `blockyworld:default` (`terrain_generator.gd`): altura por simplex fractal,
  biomas por ponto de clima mais próximo (temperatura/umidade) com altura
  misturada entre biomas (sem penhascos nas bordas), cavernas por ruído 3D,
  e features (árvores, cactos) configuradas pelos JSON de bioma.
- `blockyworld:lab`: Blocky Lab.

Determinismo: mesma seed + mesmo conteúdo = mesmo mundo. Features usam hash
posicional (`WorldHash`) e são avaliadas numa margem de 3 blocos em volta do
chunk, então árvores que cruzam bordas ficam idênticas não importa a ordem de
geração (há teste para isso).

### Meshing

`ChunkMesher` (worker thread) recebe um `ChunkSnapshot` (cópia do chunk e dos
8 vizinhos na faixa de altura necessária) e produz `SectionMeshData`:

- **face culling**: uma face só existe se o vizinho naquela direção não a
  oculta (blocos opacos ocultam; transparentes iguais se fundem, ex. vidro);
- **ambient occlusion por vértice** (3 vizinhos por canto), com a diagonal do
  quad escolhida para não criar vincos;
- duas superfícies: opaca e *cutout* (folhas, vidro);
- triângulos de colisão só para faces visíveis de blocos com colisão.

**Pronto para greedy meshing**: as UVs estão em unidades de bloco e a camada
da textura vai em `UV2.x`, lida de um `Texture2DArray` com repeat. Um quad
mesclado de N×M blocos só precisa de UVs `0..N`/`0..M` — nenhuma mudança no
shader ou no atlas. O greedy não foi ligado na 0.1 por prioridade de
estabilidade e porque interage com o AO por vértice (exige mesclar apenas
faces com o mesmo AO).

### Threading e streaming (`ChunkManager`)

```
fila de carga ──► [worker] carrega do disco ou gera ──► resultado (mutex)
                                                          │
       main thread: integra dados (com orçamento de tempo) ◄┘
                    │ todos os 8 vizinhos têm dados?
                    ▼
fila de mesh ──► [worker] malha seções do snapshot ──► resultado (mutex)
                                                          │
       main thread: cria ArrayMesh + ConcavePolygonShape3D ◄┘
```

- Jobs rodam no `WorkerThreadPool` via `JobRunner`, que rastreia e aguarda
  todas as tarefas (exigência da Godot) e permite `wait_all()` no shutdown.
- Workers só leem argumentos imutáveis: snapshot copiado, `MeshingContext`
  (tabelas planas por runtime id) e o gerador (somente leitura após `setup`).
  Hot reload cria um contexto/gerador novo; jobs antigos terminam com o antigo.
- Integração na thread principal limitada a `MAIN_THREAD_BUDGET_USEC` (4 ms)
  por frame; jobs simultâneos limitados a `cpu - 1` (máx. 6).
- Prioridade por distância ao jogador; edições do jogador furam a fila.
- Cada seção tem uma revisão; resultados antigos que chegam depois de um mais
  novo são descartados (jobs terminam fora de ordem).
- Dados mantidos até `render_distance + 1` (o anel externo alimenta culling e
  AO), descarga além de `+ UNLOAD_MARGIN`. Chunks modificados são salvos ao
  descarregar.

Medido (CPU deste ambiente, uma thread, GDScript): geração ≈ 5,6 ms/chunk,
meshing ≈ 13,7 ms/chunk (≈ 3 ms por seção). Com 3+ workers, a distância 6
enche em cerca de 1 s; uma edição custa ~3 ms de meshing em background.

### Colisão

Uma `StaticBody3D` por chunk com um `ConcavePolygonShape3D` por seção, gerado
das faces visíveis. Entidades usam `CharacterBody3D` com caixa. O raycast de
interação **não** usa física: `VoxelRaycast` percorre a grade (Amanatides &
Woo) e devolve bloco, face e célula de colocação exatos.

## Entidades (composição)

`Entity` (`CharacterBody3D`) = definição JSON + `AttributeSet` + componentes
(`EntityComponent`, nós filhos executados em ordem) + `CharacterModel`.

- `blockyworld:movement`: locomoção por `MovementIntent` com modos
  (`walk`, `fly`; futuros: nadar, escalar, montaria) — `MovementMode`.
- `blockyworld:health`: vida limitada por `blockyworld:max_health`, dano via
  evento cancelável.
- `blockyworld:wander`: IA mínima de vagar.

Controladores (input do jogador, IA) só escrevem a *intenção*; a locomoção é a
mesma para todos. O jogador é uma entidade comum (`blockyworld:player` no JSON)
com input, câmera, inventário e interação acoplados.

Um dragão futuro seria só JSON: `movement(modes: walk, fly) + health +
hostile_ai + fire_attack + loot`, cada componente registrado em código (ou
Lua) uma vez.

Escolha consciente: `Entity` estende `CharacterBody3D` porque mobs, NPCs e
jogadores são personagens. Veículos/projéteis que precisarem de outro corpo
físico podem ganhar um tipo de corpo próprio sem mudar componentes.

### Atributos

`AttributeDefinition` (JSON) + `AttributeSet` por entidade: valor base +
modificadores nomeados (`ADD`, `MULTIPLY`) com origem namespaced. A velocidade
e o pulo do jogador já vêm de atributos. `magic:mana` ou `dragonball:ki` são
apenas novos JSON de atributo.

### Modelos e attachments

`ModelDefinition` (JSON) aponta para um `.glb` e mapeia ossos e clipes:
attachment points lógicos (`head`, `face`, `chest`, `back`, `left_hand`,
`right_hand`, `waist`, `feet`) viram `BoneAttachment3D` nos ossos indicados;
animações lógicas (`idle`, `walk`, `run`, `jump`, `fall`) mapeiam para clipes
do `AnimationPlayer`. Sem o arquivo, um placeholder com os **mesmos**
attachment points é gerado — código de gameplay nunca depende do placeholder.
Ver [Assets.md](Assets.md).

## Eventos

`EventBus` (em `Game.events`): `subscribe(id, callable, prioridade)`,
`emit(id, payload)`. Eventos `*_ing` são canceláveis
(`payload.cancelled = true`). Ids em `core/events.gd`: `block_breaking`,
`block_broken`, `block_placing`, `block_placed`, `player_spawned`,
`player_moved` (troca de célula, não a cada frame), `entity_spawned`,
`entity_removed`, `entity_damaging`, `entity_died`, `chunk_loaded`,
`chunk_unloaded`, `world_loaded`, `world_saved`, `world_unloading`,
`content_loaded`, `content_reloaded`. Só a thread principal emite (emitir de
worker é reportado como erro).

## Renderização

- Todas as texturas de faces de blocos num **Texture2DArray** (mipmaps,
  filtro nearest). Tamanho da camada = maior PNG real encontrado (16 por
  padrão); texturas de tamanhos diferentes são redimensionadas com aviso.
- Dois `ShaderMaterial` (opaco e cutout) compartilhados por todos os chunks →
  poucas trocas de estado; uma draw call por superfície por seção.
- Sem sombras dinâmicas por padrão; luz direcional + céu procedural + névoa de
  profundidade perto da distância de renderização.
- Ícones de hotbar: cubo isométrico desenhado na CPU a partir das texturas.

## Assets (`ResourceManager`)

Nenhum código monta caminhos de assets. Tudo é pedido por id
(`example:blocks/ruby_block`) e resolvido em: resource packs (prioridade) →
pack/mod dono do namespace. PNG é lido do arquivo bruto (funciona para mods
externos e para `/reload`); em builds exportados, cai para o recurso importado.
`.glb/.gltf` externos são carregados em runtime com `GLTFDocument`. Assets
ausentes viram placeholders registrados no relatório `/assets`.

## Save

Ver [SaveFormat.md](SaveFormat.md). Resumo: `world.json` (metadados + paleta),
`player.json`, `chunks/c.X.Z.bwc` binário (RLE + zstd) **apenas para chunks
modificados**; chunks intocados são regenerados pela seed. Escrita atômica
(arquivo temporário + rename). Salvar não bloqueia o jogo: o snapshot é copiado
na thread principal e escrito em background; um chunk na fila de escrita é
servido da memória se for recarregado antes de o arquivo existir.

## Entrada e plataformas

- Ações abstratas (`InputActions`) instaladas em runtime, se o projeto não as
  definir. Toque/gamepad = novos eventos para as mesmas ações.
- `Settings` reduz a distância padrão em mobile; UI com `stretch_mode =
  canvas_items` e âncoras (escala com a resolução).
- Mods descobertos também em `user://mods` (funciona em Android).
- Nenhuma dependência nativa: o mesmo projeto exporta para Windows, Linux e
  Android. Renderizador Forward+ no desktop, Mobile em dispositivos móveis,
  Compatibility (OpenGL) disponível para hardware fraco.

## Logging

`Log.info/warn/error(categoria, mensagem)` → `[MOD] ...`, `[WARN][SAVE] ...`,
`[ERROR][CONTENT] ...`. Avisos/erros também vão para `push_warning/push_error`
(aparecem no depurador do editor com stack). Thread-safe; o console lê o
histórico por polling. A Godot ainda grava `user://logs/godot.log`.

## Onde estender

| Quero... | Faça |
|----------|------|
| Novo bloco/item/bioma/atributo/entidade | JSON num Content Pack ([ContentPacks.md](ContentPacks.md)) |
| Novo componente de entidade | classe `EntityComponent` + `registries.components.register_type()` no LOAD_CORE |
| Novo gerador de mundo | classe `WorldGenerator` + `registries.generators.register_type()` |
| Nova decoração de terreno | classe `TerrainFeature` + `registries.features.register_type()`, usar em `features` do bioma |
| Novo comando | `Game.commands.register("ns:nome", uso, descrição, handler)` |
| Reagir a algo | `Game.events.subscribe(Events.BLOCK_BROKEN, ...)` |
| Novo modo de movimento | classe `MovementMode` + adicionar em `MovementComponent._create_mode` |
