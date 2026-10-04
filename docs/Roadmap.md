# Roadmap

## 0.1 — Foundation (estado atual)

| Sistema | Estado |
|---------|--------|
| Chunks em colunas 16×128×16 com seções de meshing | feito |
| Geração procedural com seed: Plains, Forest, Desert, cavernas, árvores, cactos | feito |
| Face culling + AO por vértice, texture array, 2 materiais | feito |
| Geração/meshing assíncronos, streaming com filas, orçamento por frame | feito |
| Colisão por seção de chunk | feito |
| Jogador: andar, correr, pular, gravidade, colisão, voo (criativo/debug), 1ª/3ª pessoa | feito |
| Quebrar (com dureza) / colocar / pegar bloco, raycast exato | feito |
| Hotbar 9 slots, inventário 36 slots, ItemStack com metadata | feito |
| Registries namespaced: blocos, itens, atributos, biomas, modelos, entidades, componentes, geradores, features | feito |
| Mod loader: descoberta, validação, dependências, ciclos, versões, ativar/desativar | feito |
| Content Packs JSON (o jogo base usa o mesmo caminho) | feito |
| `example_mod` (bloco + item, textura PNG real) | feito |
| Save por chunk modificado, paleta por mundo, mods ausentes preservados, escrita atômica | feito |
| Entidades por composição, atributos com modificadores, test dummy | fundação |
| CharacterModel com attachment points e mapeamento de ossos/animações | fundação (sem rig real ainda) |
| Event bus com eventos canceláveis | feito |
| Console (`/help` ... `/reload`), overlay F3, Blocky Lab | feito |
| Hot reload de JSON e texturas | feito (limitado, ver Modding.md) |
| Menus: principal, mundos, criar, mods, configurações, pausa | feito |
| Testes: 78 unitários + smoke ponta a ponta | feito |

### Limitações conhecidas da 0.1 (honestas)

- **Testado sem GPU real**: renderização verificada com OpenGL por software
  (Mesa llvmpipe) em Xvfb e por screenshots; desempenho e aparência em
  hardware real (Vulkan/Forward+) ainda precisam de teste manual.
- **Sensação de controle** (aceleração, pulo, sensibilidade) ajustada por
  valores razoáveis e testada por automação, não por um jogador humano.
- **Android**: arquitetura preparada (ações abstratas, `user://mods`,
  distância menor em mobile, sem dependências nativas), mas sem controles
  touch e sem export testado.
- Sem iluminação por blocos (`light` é armazenado, não renderizado), sem água.
- Entidades não são salvas; o dummy do Blocky Lab é recriado ao entrar.
- Itens quebrados vão direto para o inventário (sem item dropado no chão);
  se o inventário estiver cheio, o excedente é perdido com aviso.
- Uma `ConcavePolygonShape3D` por seção para todos os chunks carregados
  (simples; poderia ser limitado ao redor das entidades).
- Chunks não modificados não são salvos: mudar o algoritmo do gerador muda
  terreno ainda não editado (há `generator_version` para detectar).
- Um arquivo por chunk; mundos muito grandes vão querer arquivos de região.
- Starter kit do jogador definido em código (`GameSession.STARTER_KIT`).
- Hot reload não recarrega código nem remove blocos já registrados.

### Próximas otimizações técnicas

1. Greedy meshing (formato já compatível; precisa respeitar AO).
2. Armazenamento por seção com paleta (menos memória, seções vazias grátis).
3. Colisão só perto de entidades; LOD/merge de seções distantes.
4. Mesher nativo (GDExtension) **apenas se** o perfil em hardware alvo pedir.
5. Arquivos de região e salvar chunks gerados ao trocar `generator_version`.

## 0.2 — Living World

Entidades salvas, criaturas, combate, animações com rigs reais, crafting,
itens dropados no chão, modos de jogo (survival/criativo), kits por JSON.

## 0.3 — World Expansion

Biomas avançados, estruturas, cavernas melhores, minérios, API de geração
(features e geradores registráveis por mods), água.

## 0.4 — Modding

Lua com API controlada (eventos, comandos, componentes), entidades
customizadas por script, API de UI, API de partículas, resource packs na UI.

## 0.5 — Advanced Modding

Frameworks de energia/atributos (mana, ki, energia), habilidades,
transformações, attachments e equipamentos completos, dimensões.
