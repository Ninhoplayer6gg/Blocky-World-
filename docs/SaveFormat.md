# Formato de save

```
user://saves/
└── <pasta_do_mundo>/
    ├── world.json        metadados + paleta de blocos (JSON)
    ├── player.json       estado do jogador (JSON)
    └── chunks/
        └── c.<x>.<z>.bwc chunks modificados (binário)
```

Prioridades: confiabilidade, versionamento e migração. Dados pequenos e
legíveis em JSON; dados grandes em binário compacto.

## Quando salva

- Só **chunks modificados** são escritos. Chunks nunca alterados são
  regenerados pela seed (mesmo gerador → mesmo resultado).
- Ao descarregar um chunk modificado, a cada 60 s (autosave), em
  **Pause → Save**, `/save`, ao voltar ao menu e ao fechar a janela.
- A escrita roda em background a partir de uma cópia; se o chunk for
  recarregado antes de o arquivo existir, a cópia em memória é usada.

## Escrita segura

Todo arquivo é escrito em `<arquivo>.tmp` e renomeado por cima do original
(`save/safe_file.gd`). Uma queda no meio do save deixa a versão anterior
intacta; se só sobrar o `.tmp`, ele é usado na leitura.

## world.json

```json
{
  "format": "blockyworld.world",
  "save_version": 1,
  "game_version": "0.1.0",
  "name": "Meu Mundo",
  "seed": 424242,
  "generator": "blockyworld:default",
  "generator_version": 1,
  "creative": false,
  "created_at": "2026-10-04T22:00:00",
  "last_played": "2026-10-04T23:10:00",
  "mods": [{"id": "blockyworld", "version": "0.1.0"}, {"id": "example_mod", "version": "0.1.0"}],
  "block_palette": ["blockyworld:air", "blockyworld:stone", "example:ruby_block"]
}
```

- `seed`: número já resolvido (o texto digitado é convertido uma vez).
- `mods`: mods ativos. Mods que faltaram numa sessão continuam listados para
  o aviso reaparecer.
- `block_palette`: **world id** (índice) → id namespaced. A posição 0 é sempre
  `blockyworld:air`. Entradas só são adicionadas, nunca reordenadas.

### Paleta e runtime ids

Dentro do jogo, chunks usam runtime ids (ordem de registro da sessão). No
disco, usam world ids. Ao abrir o mundo, `WorldSave.bind_blocks()` cria as
tabelas `world → runtime` e `runtime → world`. Por isso adicionar, remover ou
reordenar mods não embaralha os blocos de um mundo.

### Mods ausentes

Ids da paleta que nenhum mod registra ganham um bloco placeholder (textura
magenta/preta, não colocável) que **mantém o id original**. O chunk é salvo
com o id original; reinstalar o mod restaura os blocos. O menu avisa antes de
abrir o mundo.

## Arquivo de chunk (`.bwc`)

Little endian:

| Campo | Tipo | Valor |
|-------|------|-------|
| magic | 4 bytes | `BWCK` |
| format | u16 | 1 (`ChunkSerializer.FORMAT_VERSION`) |
| cx, cz | i32, i32 | coordenadas do chunk |
| sx, sy, sz | u16 ×3 | dimensões com que foi salvo (16, 128, 16) |
| compression | u8 | 1 = zstd |
| raw_size | u32 | tamanho do payload descomprimido |
| data_size | u32 | tamanho do payload comprimido |
| payload | bytes | zstd de: `u32 runs` + `runs × (u16 comprimento, u16 world_id)` |

O payload é RLE na ordem do array (`x + z*16 + y*256`), depois zstd. Um chunk
típico tem poucos KB.

Validações na leitura: magic, versão (mais nova = recusa), dimensões, tamanho,
descompressão, ids dentro da paleta, cobertura exata do volume e coordenadas
batendo com o nome do arquivo. Arquivo inválido é **renomeado para
`.corrupt`** (não é apagado), o erro vai para o log e o chunk é regenerado.

## player.json

```json
{
  "version": 1,
  "position": [0.5, 55.9, -6.5],
  "yaw": 0.0,
  "pitch": -0.3,
  "selected_slot": 2,
  "inventory": [{"slot": 0, "item": "blockyworld:grass", "amount": 63},
                {"slot": 9, "item": "example:ruby", "amount": 4, "metadata": {"example:shine": 2}}],
  "components": {"blockyworld:movement": {"mode": "walk"}, "blockyworld:health": {"current": 20}}
}
```

Itens desconhecidos são mantidos como estão. Se a posição salva estiver
dentro de blocos (ex. o terreno mudou), o jogador é levado para a superfície.
O nome é `player.json` (não `.dat`) porque o conteúdo é JSON legível.

Entidades (mobs) ainda não são salvas na 0.1 (planejado para a 0.2, com
`EntityComponent.save_state/load_state` já existindo).

## Versionamento

| Constante | Onde | Quando incrementar |
|-----------|------|--------------------|
| `GameInfo.SAVE_VERSION` | `core/game_info.gd` | mudou `world.json`/layout da pasta |
| `ChunkSerializer.FORMAT_VERSION` | `save/chunk_serializer.gd` | mudou o binário do chunk |
| `generator_version` | por gerador | mudou o algoritmo de geração |

Saves de versão **mais nova** são recusados com mensagem clara. Saves mais
antigos passam por `SaveMigrations.migrate_world()`, uma etapa por versão
(`_v1_to_v2`, ...), nunca editando etapas antigas.

Pendência conhecida: chunks não modificados são regenerados; se o algoritmo
de um gerador mudar, `generator_version` permite detectar a diferença, mas a
regeneração "congelada" (salvar chunks gerados) ainda não existe — ver
Roadmap.
