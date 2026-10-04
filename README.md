# Blocky World

Sandbox voxel 3D original, construído desde o primeiro dia como **plataforma de
modding**: o conteúdo do jogo base (pedra, terra, grama, biomas, o próprio
jogador) é registrado pelos mesmos registries e pelo mesmo formato de Content
Pack que qualquer mod usa.

Versão atual: **0.1.0 — Foundation** (veja [docs/Roadmap.md](docs/Roadmap.md)).

## Requisitos

- **Godot 4.3 ou mais novo** (versão padrão, não .NET). Testado em 4.3-stable
  e 4.7-stable.
- Nenhuma dependência externa, plugin ou GDExtension.

## Como rodar

1. Abra o Godot e importe `project.godot`.
2. Pressione F5. A cena principal é `res://ui/main_menu.tscn`.

Pela linha de comando:

```bash
godot --path .                    # abre o jogo
godot --path . --rendering-method gl_compatibility   # GPUs antigas / sem Vulkan
```

## Controles (teclado e mouse)

| Ação | Tecla |
|------|-------|
| Andar | W A S D |
| Pular / subir (voando) | Espaço |
| Correr | Shift |
| Descer (voando) | Ctrl |
| Quebrar bloco / atacar entidade | Botão esquerdo (segurar) |
| Colocar bloco | Botão direito |
| Pegar bloco mirado | Botão do meio |
| Hotbar | 1–9, roda do mouse |
| Voar (mundos criativos, ex. Blocky Lab) | F |
| Primeira/terceira pessoa | F5 |
| Tela de debug | F3 |
| Console | ` ou F1 (ou `/` já com a barra) |
| Pausar | Esc |

Todas as teclas passam por *Input Actions* abstratas
([core/input_actions.gd](core/input_actions.gd)); nenhum script consulta teclas
diretamente, o que deixa o caminho livre para controles touch e remapeamento.

## Console de desenvolvedor

`/help`, `/give <item> [qtd]`, `/setblock <x> <y> <z> <bloco>`, `/tp <x> <y> <z>`,
`/spawn <entidade> [x y z]`, `/reload`, `/chunks`, `/fps`, `/seed`, `/save`,
`/fly`, `/rd <chunks>`, `/mods`, `/blocks`, `/items`, `/entities`, `/assets`,
`/pos`, `/clear`. Coordenadas aceitam `~` (relativo ao jogador). O console
também mostra o log do jogo.

## Blocky Lab

Botão **Blocky Lab** no menu: mundo plano de desenvolvimento, criativo (voo,
quebra instantânea, itens infinitos), com:

- todos os blocos registrados (jogo base **e mods**) em fila em `z = -4`,
  bem na frente de quem nasce;
- escada e saltos em `z = 8` (atrás do spawn) para testar movimento e colisão;
- parede de vidro em `x = -6` para testar transparência e culling;
- piso com linhas escuras nas bordas de chunk;
- um *test dummy* (entidade com IA de vagar e vida) criado ao entrar.

## Estrutura

```
core/          boot, Game (autoload), registries genéricos, eventos, log, config, assets
modding/       descoberta/validação/dependências de mods, Content Packs JSON
blocks/ items/ inventory/ attributes/   definições e registries de conteúdo
voxel/         dados de chunk, coordenadas, snapshot, mesher, raycast
world/         World, streaming de chunks, geradores, biomas, sessão de jogo
entities/      Entity, componentes, modelos de personagem, attachments
player/        Player (entidade + input + câmera + inventário)
interaction/   quebrar/colocar/mirar
rendering/     texture array de blocos, shaders, placeholders, ícones, ambiente
save/          formato de mundo, chunks binários, migrações, escrita segura
debug/         console, comandos, overlay de debug
ui/            menu principal, HUD, pausa
packs/blockyworld/   conteúdo base (é um "mod" embutido)
mods/example_mod/    mod de demonstração (1 bloco + 1 item, zero código)
tests/         testes unitários e smoke test ponta a ponta
tools/         scripts de verificação, benchmark e captura de tela
docs/          documentação de arquitetura, modding e formatos
```

## Testes

```bash
GODOT=/caminho/para/godot tools/run_tests.sh          # compila todos os scripts + testes unitários
SMOKE=1 GODOT=/caminho/para/godot tools/run_tests.sh  # + smoke test do milestone (cria, salva, recarrega)
```

- **78 testes unitários** (registries, IDs, itens/inventário, coordenadas,
  dados de chunk, serialização, mod loader e dependências, Content Packs,
  geração determinística, save/load com mods ausentes, mesher, raycast,
  eventos, atributos, assets e glTF em runtime).
- **Smoke test** (`tests/smoke/milestone_smoke.gd`): roda o jogo de verdade,
  cria um mundo, anda, pula, quebra e coloca blocos, usa o bloco do
  `example_mod`, atravessa chunks, roda `/reload`, salva, e num **segundo
  processo** reabre o mundo e confere que tudo persistiu.
- `tools/benchmark_chunks.gd` mede custo de geração/meshing por chunk.
- `tools/capture_lab.gd` tira um screenshot do Blocky Lab (precisa de display
  ou `xvfb-run`).

## Documentação

- [Architecture.md](docs/Architecture.md) — como o motor funciona e por quê
- [Modding.md](docs/Modding.md) — criar, instalar e depurar mods
- [ContentPacks.md](docs/ContentPacks.md) — referência dos JSON de conteúdo
- [Assets.md](docs/Assets.md) — onde colocar modelos, texturas, animações, ícones
- [SaveFormat.md](docs/SaveFormat.md) — formato dos saves e versionamento
- [Roadmap.md](docs/Roadmap.md) — estado atual e próximos passos

## Estado do Milestone 0.1

Verificado automaticamente (smoke test, Godot 4.3 e 4.7): criar mundo, nascer
no mundo voxel, andar, pular, quebrar, colocar, trocar slot da hotbar,
atravessar chunks com geração de novos chunks, salvar, reabrir em outro
processo com as alterações preservadas, carregar `example_mod` e usar o bloco
dele. Verificado visualmente por screenshots (renderização OpenGL por
software). Itens que dependem de hardware real e de "sensação" — conforto do
controle, desempenho numa GPU real, Android — ainda precisam de teste manual;
veja as limitações conhecidas em [docs/Roadmap.md](docs/Roadmap.md).
