# Modding

Na 0.1 os mods são **declarativos**: JSON (Content Packs) + assets (PNG,
glTF). Scripts Lua chegam na 0.4, através de uma API controlada (mods não
terão acesso irrestrito ao motor). Tudo que está aqui é exatamente o que o
jogo base usa para registrar o próprio conteúdo.

## Onde instalar

O jogo procura mods, nesta ordem de prioridade (um id duplicado encontrado
depois é rejeitado):

| Local | Uso |
|-------|-----|
| `res://packs/` | conteúdo embutido (o jogo base, `blockyworld`) |
| `res://mods/` | mods empacotados com o projeto (ex. `example_mod`) |
| `user://mods/` | mods do jogador (desktop e Android). Botão **Open Mods Folder** no menu Mods |
| `<pasta do executável>/mods/` | builds exportados para desktop |

`user://` no Linux é `~/.local/share/godot/app_userdata/Blocky World/`, no
Windows `%APPDATA%\Godot\app_userdata\Blocky World\`.

## Estrutura de um mod

```
mods/
└── example_mod/
    ├── mod.json
    ├── content/          JSON de conteúdo (ver ContentPacks.md)
    │   ├── blocks/
    │   ├── items/
    │   ├── attributes/
    │   ├── biomes/
    │   ├── models/
    │   └── entities/
    ├── textures/         PNG (blocks/, items/, ...)
    ├── models/           .glb / .gltf
    ├── animations/       (reservado)
    ├── sounds/           (reservado)
    └── scripts/          (reservado para Lua, 0.4)
```

Só `mod.json` é obrigatório. O nome da pasta deveria ser igual ao id (há um
aviso se não for).

## mod.json

```json
{
  "id": "example_mod",
  "name": "Example Mod",
  "version": "0.1.0",
  "author": "Example",
  "description": "Example Blocky World mod",
  "namespace": "example",
  "api_version": 1,
  "dependencies": [
    "core_library",
    {"id": "blockyworld", "version": ">=0.1.0"}
  ],
  "optional_dependencies": ["some_other_mod"]
}
```

| Campo | Obrigatório | Regras |
|-------|-------------|--------|
| `id` | sim | 2–64 caracteres `a-z 0-9 _`, começando com letra |
| `name` | sim | texto não vazio |
| `version` | sim | `MAJOR.MINOR.PATCH` (ex. `1.2.0`) |
| `author`, `description` | não | texto |
| `namespace` | não | prefixo dos ids de conteúdo; padrão = `id` |
| `api_version` | não | API de mod alvo (atual: `1`). Maior que a do jogo = erro; menor = aviso |
| `dependencies` | não | ids, ou `{"id", "version"}` com `*`, `1.2.3`, `>=`, `>`, `<=`, `<`, `^` |
| `optional_dependencies` | não | só afetam a ordem de carregamento se presentes |

O namespace `blockyworld` é reservado para o jogo base.

## Validação e erros

Um mod inválido **nunca fecha o jogo**. Ele aparece em **Mods** com estado
`Error` e a mensagem, e no log/console (`/mods`). Exemplos de mensagens:

- `mod.json line 4: Expected ',' or '}' after value`
- `missing required field 'version'`
- `invalid id 'My Mod': use 2-64 lowercase letters, digits or '_'...`
- `duplicate mod id 'gems' (already provided by res://mods/gems)`
- `requires mod 'core_library', which is not installed`
- `requires mod 'gems', which failed to load`
- `requires 'gems' >=2.0.0 but version 1.0.0 is installed`
- `dependency cycle between: a, b`
- `the id/namespace 'blockyworld' is reserved for the base game`

Erros dentro de arquivos de conteúdo afetam só aquela definição; o resto do
mod carrega e o mod mostra `Loaded (N problem(s))`.

## Ordem de carregamento

1. Packs embutidos primeiro (`blockyworld`).
2. Depois, ordem topológica das dependências; empates em ordem alfabética.
3. O conteúdo é carregado **por tipo** em todos os mods (todos os blocos,
   depois todos os itens, ...), então um item pode referenciar o bloco de
   outro mod sem depender da ordem dos arquivos.

A ordem é determinística, então runtime ids são estáveis entre execuções com
o mesmo conjunto de mods — mas os saves **não** dependem disso (paleta por
mundo).

## Ativar/desativar

Menu **Mods** → interruptor *Enabled* (salvo em `user://mods.cfg`, vale a
partir do próximo início). Mods que dependem de um mod desativado são
marcados com erro explicando o motivo.

## Mundos e mods ausentes

`world.json` guarda os mods ativos. Ao abrir um mundo sem um deles, o menu
avisa e pede confirmação. Blocos do mod ausente viram placeholders
(textura magenta/preta) que **guardam o id original**: salvar o mundo não
apaga nada, e reinstalar o mod traz os blocos de volta. Itens de mods
ausentes no inventário também são preservados.

## Hot reload

`/reload` relê mods e JSON, reconstrói texturas e remalha os chunks
carregados, sem fechar o mundo:

- propriedades de blocos/itens existentes são atualizadas;
- blocos/itens novos são adicionados;
- blocos removidos do JSON continuam registrados até reiniciar (para não
  invalidar o mundo carregado);
- texturas novas/alteradas em PNG aparecem na hora;
- código (GDScript) não é recarregado.

## Passo a passo: seu primeiro mod

1. Crie `user://mods/gems/mod.json`:
   ```json
   {"id": "gems", "name": "Gems", "version": "1.0.0", "dependencies": ["blockyworld"]}
   ```
2. Crie `user://mods/gems/content/blocks/sapphire_block.json`:
   ```json
   {
     "id": "gems:sapphire_block",
     "display_name": "Sapphire Block",
     "texture": "gems:blocks/sapphire_block",
     "placeholder_color": "#2050d0",
     "hardness": 3
   }
   ```
3. (Opcional) desenhe `user://mods/gems/textures/blocks/sapphire_block.png`
   (16×16).
4. Abra o jogo (ou `/reload` dentro de um mundo) e use
   `/give gems:sapphire_block`. No Blocky Lab o bloco aparece na fila de
   exposição.

## O que mods ainda não podem fazer (0.1)

- Executar código (Lua chega na 0.4).
- Registrar novos *tipos* de componente, gerador ou feature (exigem código;
  a API Lua vai expor esses mesmos registries).
- Sobrescrever conteúdo de outro namespace (planejado como "overrides"
  explícitos).
- Eventos já existem e são o contrato que a API de scripts vai expor; hoje só
  código GDScript pode assiná-los.
