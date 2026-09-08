# FPU Top Level — `fpu`

## Descrição Geral

O módulo `fpu` implementa o nível superior da unidade de ponto flutuante,
integrando os blocos responsáveis por:

- soma em ponto flutuante;
- subtração em ponto flutuante;
- multiplicação em ponto flutuante.

A unidade recebe dois operandos de 32 bits no formato IEEE 754 de precisão
simples e seleciona o subsistema adequado de acordo com o código presente na
entrada `op`.

A arquitetura utiliza uma interface única para todas as operações:

- `a` e `b` fornecem os operandos;
- `op` seleciona a operação;
- `start` solicita o início do processamento;
- `result` fornece o resultado final;
- `done` indica quando a operação foi concluída;
- `overflow` e `underflow` informam condições relacionadas ao expoente;
- `guard`, `round` e `sticky` disponibilizam informações auxiliares geradas
  pelo caminho de multiplicação.

O módulo também registra os operandos e o código da operação no início de cada
transação, mantendo essas informações estáveis durante todo o processamento.

---

# Organização dos Operandos

Os operandos `a` e `b` possuem 32 bits e seguem a organização utilizada pelo
formato IEEE 754 de precisão simples:

```text
31          30                    23 22                     0
┌───────────┬──────────────────────┬────────────────────────┐
│   Sinal   │      Expoente        │       Mantissa         │
│   1 bit   │       8 bits         │        23 bits         │
└───────────┴──────────────────────┴────────────────────────┘
```

Assim:

```text
bit 31     → sinal
bits 30:23 → expoente
bits 22:0  → mantissa
```

O bloco de soma/subtração recebe diretamente as palavras de 32 bits.

Para o multiplicador, o `top_level` separa internamente esses campos e os
encaminha para as entradas específicas de `fpu_mult_top`.

---

# Interface do Módulo

## Entradas

| Sinal | Largura | Descrição |
|---|---:|---|
| `clk` | 1 bit | Clock principal da FPU |
| `rst_n` | 1 bit | Reset assíncrono ativo em nível baixo |
| `start` | 1 bit | Solicita o início de uma nova operação |
| `op` | 2 bits | Seleciona a operação |
| `a` | 32 bits | Operando A em formato IEEE 754 |
| `b` | 32 bits | Operando B em formato IEEE 754 |

---

## Saídas

| Sinal | Largura | Descrição |
|---|---:|---|
| `result` | 32 bits | Resultado final da operação |
| `done` | 1 bit | Indica que `result` está disponível |
| `guard` | 1 bit | Bit Guard proveniente do caminho de multiplicação |
| `round` | 1 bit | Bit Round proveniente do caminho de multiplicação |
| `sticky` | 1 bit | Bit Sticky proveniente do caminho de multiplicação |
| `overflow` | 1 bit | Indica condição de overflow da operação |
| `underflow` | 1 bit | Indica condição de underflow da operação |

---

# Códigos de Operação

A seleção da operação é realizada através da entrada `op`.

| `op` | Operação | Unidade utilizada |
|---|---|---|
| `2'b00` | Soma | `fpu_sum_sub` |
| `2'b01` | Subtração | `fpu_sum_sub` |
| `2'b10` | Multiplicação | `fpu_mult_top` |
| `2'b11` | Reservado | Nenhuma unidade aritmética |

Os códigos podem ser representados por:

```text
00 → ADD
01 → SUB
10 → MUL
11 → RES
```

---

# Organização Geral da Arquitetura

A estrutura funcional da FPU pode ser representada por:

```text
                           ┌──────────────────────────────┐
                           │             fpu              │
                           │                              │
        a[31:0] ──────────►│   ┌─────────────────────┐    │
        b[31:0] ──────────►│   │ Registradores       │    │
        op[1:0] ──────────►│   │ a_reg / b_reg       │    │
        start ────────────►│   │ op_reg              │    │
                           │   └──────────┬──────────┘    │
                           │              │               │
                           │       ┌──────┴──────┐        │
                           │       │             │        │
                           │       ▼             ▼        │
                           │ ┌─────────────┐ ┌──────────┐ │
                           │ │ fpu_sum_sub │ │ mult     │ │
                           │ │             │ │ top      │ │
                           │ │ ADD / SUB   │ │ MUL      │ │
                           │ └──────┬──────┘ └────┬─────┘ │
                           │        │             │       │
                           │        └──────┬──────┘       │
                           │               ▼              │
                           │       ┌───────────────┐      │
                           │       │ Seleção final │      │
                           │       │ result/flags  │      │
                           │       └───────┬───────┘      │
                           │               │              │
                           └───────────────┼──────────────┘
                                           │
                                           ▼
                                      result[31:0]
```

A unidade superior não realiza diretamente as operações aritméticas.

Sua função principal é:

1. receber a solicitação;
2. armazenar os operandos;
3. armazenar a operação;
4. selecionar o subsistema correto;
5. aguardar a conclusão;
6. capturar o resultado;
7. encaminhar as flags;
8. gerar uma interface única para o restante do sistema.

---

# 1. Registro dos Operandos e da Operação

Quando `start` é ativado e a FPU está livre, o módulo armazena:

```text
a      → a_reg
b      → b_reg
op     → op_reg
```

Esses registradores formam uma cópia interna da operação solicitada.

---

## Motivo do registro das entradas

Os blocos internos possuem latências diferentes e podem utilizar os operandos
por vários ciclos.

O `fpu_sum_sub`, por exemplo, executa sequencialmente etapas de:

- unpack;
- alinhamento;
- operação aritmética;
- normalização;
- arredondamento;
- finalização.

Além disso, a normalização pode exigir múltiplos ciclos.

Se os blocos internos fossem ligados diretamente às entradas externas, uma
mudança em `a`, `b` ou `op` durante a execução poderia modificar uma operação
que ainda estivesse em andamento.

Por esse motivo, as entradas são congeladas no início da transação.

A estrutura é:

```text
                 start
                   │
                   ▼
         ┌───────────────────┐
a ──────►│                   │
b ──────►│ Registrar entrada │
op ─────►│                   │
         └─────────┬─────────┘
                   │
                   ▼
        operação permanece estável
        até a conclusão
```

---

# 2. Controle de Ocupação da FPU

O registrador interno `active` indica se existe uma operação em andamento.

Quando:

```text
active = 0
```

a unidade está livre e pode aceitar uma nova solicitação.

Quando:

```text
active = 1
```

a FPU está processando uma operação.

Enquanto `active` estiver em `1`, novas solicitações de `start` não iniciam uma
segunda operação.

---

## Início de uma operação

Uma nova transação é aceita quando:

```text
active = 0
```

e:

```text
start = 1
```

Nesse momento:

```text
a_reg  ← a
b_reg  ← b
op_reg ← op
```

e, para uma operação válida:

```text
active ← 1
```

---

## Finalização

Quando o subsistema selecionado ativa seu respectivo sinal de conclusão, o
`top_level`:

1. captura o resultado;
2. captura as flags;
3. ativa `done`;
4. limpa `active`.

Assim, a FPU volta a ficar disponível para uma nova operação.

---

# 3. Subsistema de Soma e Subtração

## `fpu_sum_sub`

As operações:

```text
ADD = 00
SUB = 01
```

são encaminhadas para o módulo `fpu_sum_sub`.

Esse subsistema recebe:

- os operandos completos de 32 bits;
- o código da operação;
- um pulso interno de início.

---

## Pulso `sum_sub_start`

O bloco `fpu_sum_sub` possui uma entrada `start`.

Para compatibilizar essa interface com o controlador superior, o `top_level`
gera internamente:

```text
sum_sub_start
```

Esse sinal é utilizado como um pulso de início da operação.

Após a solicitação, ele retorna a zero, enquanto o `fpu_sum_sub` continua seu
processamento de forma independente.

---

## Processamento interno

O caminho de soma/subtração realiza as seguintes etapas:

```text
IDLE
  ↓
UNPACK
  ↓
ALIGN
  ↓
EXECUTE
  ↓
NORMALIZE
  ↓
ROUND
  ↓
FINISH
```

Durante essas etapas, o módulo:

- extrai sinal, expoente e mantissa;
- reconstrói os significandos;
- compara os expoentes;
- alinha as mantissas;
- preserva informação Sticky;
- soma ou subtrai as magnitudes;
- determina o sinal final;
- normaliza a mantissa;
- corrige o expoente;
- realiza o arredondamento;
- reconstrói a palavra de 32 bits.

---

## Resultado de ADD/SUB

Quando:

```text
sum_sub_done = 1
```

o `top_level` captura:

```text
sum_sub_result
sum_sub_overflow
sum_sub_underflow
```

e os encaminha para as saídas principais.

---

# 4. Subsistema de Multiplicação

## `fpu_mult_top`

A operação:

```text
MUL = 10
```

é encaminhada para o módulo `fpu_mult_top`.

Esse bloco recebe os campos IEEE 754 separadamente.

Por isso, o `top_level` extrai dos operandos registrados:

```text
a_s = a_reg[31]
a_e = a_reg[30:23]
a_m = a_reg[22:0]

b_s = b_reg[31]
b_e = b_reg[30:23]
b_m = b_reg[22:0]
```

---

# Estrutura do Multiplicador

O `fpu_mult_top` integra os subsistemas:

- `fpu_mult_signal`;
- `fpu_mult_exp_calc`;
- `fpu_mult_24x24`;
- `fpu_mult_norm`.

Esses blocos são responsáveis por:

```text
sinal       → determinação do sinal do produto
expoente    → soma dos expoentes e correção do Bias
mantissa    → multiplicação dos significandos
normalização→ ajuste da mantissa e do expoente
GRS         → geração de Guard, Round e Sticky
```

---

## Controle enviado ao multiplicador

O multiplicador recebe o código `MUL` apenas enquanto existir uma operação de
multiplicação ativa.

Conceitualmente:

```text
active = 1 e op_reg = MUL
          │
          ▼
     mult_op = MUL
```

Nas demais situações:

```text
mult_op = RES
```

Isso impede que o caminho de multiplicação seja mantido ativo fora de uma
operação válida.

---

## Resultado da multiplicação

Quando:

```text
mult_done = 1
```

o `top_level` captura:

```text
mult_result
mult_guard
mult_round
mult_sticky
mult_overflow
mult_underflow
```

e os encaminha para as saídas principais.

---

# 5. Seleção do Resultado

O `top_level` funciona como um multiplexador controlado pela operação
registrada.

Conceitualmente:

```text
                   ┌───────────────┐
sum_sub_result ───►│               │
                   │    Seleção    ├──► result
mult_result ──────►│               │
                   └───────▲───────┘
                           │
                         op_reg
```

Para:

```text
op_reg = ADD
```

é utilizado o resultado do `fpu_sum_sub`.

Para:

```text
op_reg = SUB
```

também é utilizado o resultado do `fpu_sum_sub`.

Para:

```text
op_reg = MUL
```

é utilizado o resultado do `fpu_mult_top`.

---

# 6. Sinal `done`

O sinal `done` da interface externa é controlado pelo próprio `top_level`.

Cada bloco interno possui seu próprio mecanismo de conclusão:

```text
sum_sub_done
mult_done
```

O controlador superior observa apenas o sinal correspondente à operação ativa.

Quando esse sinal é detectado:

```text
resultado interno válido
        │
        ▼
captura result e flags
        │
        ▼
done = 1
```

No ciclo seguinte, a FPU retorna ao estado disponível e `done` volta a zero.

---

## Interface uniforme

Essa estrutura permite que a lógica externa não precise conhecer os tempos
internos de cada unidade.

O protocolo externo pode ser entendido como:

```text
             ┌───┐
start  ──────┘   └────────────────────

               processamento

                                  ┌───┐
done   ───────────────────────────┘   └──
```

O tempo entre `start` e `done` depende da operação executada.

---

# 7. Latência das Operações

As unidades internas não necessariamente possuem a mesma latência.

A multiplicação possui um caminho de processamento próprio, enquanto a
soma/subtração utiliza uma máquina de estados com várias etapas.

Além disso, no `fpu_sum_sub`, a normalização pode permanecer ativa por múltiplos
ciclos quando o resultado precisa ser deslocado repetidamente para a esquerda.

Consequentemente, a FPU deve ser considerada uma unidade de **latência
variável**.

Por esse motivo, a disponibilidade do resultado deve sempre ser determinada
através de:

```text
done = 1
```

e não através de uma quantidade fixa de ciclos.

---

# 8. Guard, Round e Sticky

A interface superior possui:

```text
guard
round
sticky
```

Esses sinais são exportados pelo caminho de multiplicação.

Durante:

```text
op = MUL
```

as saídas recebem:

```text
guard  ← mult_guard
round  ← mult_round
sticky ← mult_sticky
```

---

## ADD e SUB

O módulo `fpu_sum_sub` utiliza bits auxiliares internamente durante alinhamento
e arredondamento, porém não os exporta em sua interface.

Portanto, para soma e subtração, o `top_level` força:

```text
guard  = 0
round  = 0
sticky = 0
```

Assim, a interface permanece uniforme sem atribuir sinais externos que não
existem no bloco de soma/subtração.

---

# 9. Overflow e Underflow

As flags:

```text
overflow
underflow
```

são selecionadas de acordo com o subsistema responsável pela operação.

Para soma e subtração:

```text
overflow  ← sum_sub_overflow
underflow ← sum_sub_underflow
```

Para multiplicação:

```text
overflow  ← mult_overflow
underflow ← mult_underflow
```

A FPU superior não recalcula essas condições.

Ela apenas encaminha as flags produzidas pelo bloco aritmético responsável pela
operação atual.

---

# 10. Operação Reservada

O código:

```text
op = 2'b11
```

é reservado.

Quando uma solicitação é recebida com esse código, nenhuma unidade aritmética é
acionada.

O controlador produz uma resposta neutra:

```text
result    = 0
guard     = 0
round     = 0
sticky    = 0
overflow  = 0
underflow = 0
```

e sinaliza a conclusão através de `done`.

Esse código pode ser utilizado futuramente para expansão da arquitetura.

---

# 11. Reset

O reset é ativo em nível baixo:

```text
rst_n = 0
```

Quando o reset é acionado, o `top_level` retorna ao estado inicial.

São zerados:

- operandos registrados;
- código da operação;
- controle de atividade;
- pulso interno do somador/subtrator;
- resultado;
- `done`;
- Guard;
- Round;
- Sticky;
- overflow;
- underflow.

A operação registrada é colocada inicialmente no código reservado.

---

# 12. Fluxo Completo de uma Operação

O funcionamento da FPU pode ser dividido nas seguintes etapas.

## Etapa 1 — Espera

A FPU permanece disponível enquanto:

```text
active = 0
```

---

## Etapa 2 — Solicitação

A lógica externa apresenta:

```text
a
b
op
```

e ativa:

```text
start = 1
```

---

## Etapa 3 — Registro

Os valores são armazenados:

```text
a_reg  ← a
b_reg  ← b
op_reg ← op
```

---

## Etapa 4 — Seleção da unidade

O código da operação determina o destino.

```text
ADD/SUB → fpu_sum_sub
MUL     → fpu_mult_top
RES     → resposta reservada
```

---

## Etapa 5 — Processamento

A unidade selecionada executa a operação utilizando os operandos registrados.

Enquanto isso:

```text
active = 1
```

e novas operações não são aceitas.

---

## Etapa 6 — Conclusão interna

O subsistema responsável sinaliza:

```text
sum_sub_done
```

ou:

```text
mult_done
```

---

## Etapa 7 — Captura

O `top_level` registra:

- resultado;
- overflow;
- underflow;
- GRS, quando aplicável.

---

## Etapa 8 — Sinalização externa

O controlador ativa:

```text
done = 1
```

indicando que `result` contém a resposta válida.

---

## Etapa 9 — Liberação

O registrador:

```text
active
```

retorna a zero.

A FPU pode então aceitar uma nova operação.

---

# Exemplo — Soma

Considere:

```text
A = 1.0
B = 2.0
op = 00
```

A sequência é:

```text
start
  │
  ▼
registrar A, B e ADD
  │
  ▼
fpu_sum_sub
  │
  ├── UNPACK
  ├── ALIGN
  ├── EXECUTE
  ├── NORMALIZE
  ├── ROUND
  └── FINISH
  │
  ▼
sum_sub_done
  │
  ▼
result = 3.0
done   = 1
```

---

# Exemplo — Subtração

Considere:

```text
A = 5.0
B = 2.0
op = 01
```

O `top_level` registra os operandos e direciona a operação para
`fpu_sum_sub`.

O módulo interno executa:

```text
5.0 - 2.0
```

e, ao concluir:

```text
result = 3.0
done   = 1
```

---

# Exemplo — Multiplicação

Considere:

```text
A = 1.5
B = 2.0
op = 10
```

Após o registro dos operandos, o `top_level` separa:

```text
sinal
expoente
mantissa
```

e encaminha esses campos ao `fpu_mult_top`.

O multiplicador processa:

```text
1.5 × 2.0 = 3.0
```

e retorna:

```text
mult_result
mult_done
mult_guard
mult_round
mult_sticky
mult_overflow
mult_underflow
```

O controlador então disponibiliza essas informações na interface principal.

---

# Integração dos Subsistemas

A arquitetura completa pode ser resumida por:

```text
                              ┌─────────────────┐
                              │     start       │
                              │   a, b e op     │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │ Registradores   │
                              │ a_reg           │
                              │ b_reg           │
                              │ op_reg          │
                              └────────┬────────┘
                                       │
                            ┌──────────┴──────────┐
                            │                     │
                   ADD/SUB  ▼                     ▼  MUL
                    ┌────────────────┐    ┌────────────────┐
                    │  fpu_sum_sub   │    │  fpu_mult_top  │
                    │                │    │                │
                    │ soma/subtração │    │ multiplicação  │
                    └───────┬────────┘    └───────┬────────┘
                            │                     │
                            └──────────┬──────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │ Controle final  │
                              │ result          │
                              │ done            │
                              │ flags           │
                              └────────┬────────┘
                                       │
                                       ▼
                              Interface externa
```

---

# Arquivos Relacionados

| Arquivo | Função |
|---|---|
| `fpu.v` | Integra e controla todas as unidades aritméticas da FPU |
| `fpu_sum_sub.v` | Implementa soma e subtração em ponto flutuante |
| `fpu_mult_top.v` | Topo da unidade de multiplicação |
| `fpu_mult_24x24.v` | Multiplica os significandos |
| `fpu_mult_exp_calc.v` | Calcula o expoente da multiplicação |
| `fpu_mult_norm.v` | Normaliza a mantissa da multiplicação e gera GRS |
| `fpu_mult_signal.v` | Calcula o sinal da multiplicação |

---

# Resumo dos Subsistemas

| Subsistema | Operações | Função |
|---|---|---|
| `fpu_sum_sub` | ADD / SUB | Soma e subtração IEEE 754 |
| `fpu_mult_top` | MUL | Multiplicação IEEE 754 |
| Registradores de entrada | Todas | Mantêm operandos e operação estáveis |
| Controle `active` | Todas | Indica operação em andamento |
| Controle de `start` | ADD / SUB | Gera o pulso interno do somador/subtrator |
| Seletor de resultado | Todas | Encaminha a resposta da unidade ativa |
| Controle de `done` | Todas | Padroniza a indicação de conclusão |
| Seleção de flags | Todas | Encaminha overflow, underflow e GRS |

---

# Características da FPU

A arquitetura integrada possui:

- dois operandos de 32 bits;
- representação baseada em IEEE 754 de precisão simples;
- soma;
- subtração;
- multiplicação;
- código de operação de 2 bits;
- interface de início por `start`;
- sinalização de conclusão por `done`;
- operandos registrados internamente;
- proteção contra alteração das entradas durante a operação;
- latência variável;
- sinalização de overflow;
- sinalização de underflow;
- exportação de Guard, Round e Sticky para multiplicação;
- código reservado para expansão futura.

---

# Considerações sobre a Interface

A FPU utiliza um protocolo simples de requisição e conclusão.

Uma nova operação deve ser apresentada quando a unidade estiver livre.

A lógica externa deve:

1. colocar `a`, `b` e `op` nas entradas;
2. ativar `start`;
3. aguardar `done`;
4. ler `result` e as flags;
5. iniciar uma nova operação somente após a conclusão da anterior.

O tempo de processamento não deve ser inferido por uma quantidade fixa de
ciclos.

A referência para validade da saída é sempre:

```text
done = 1
```

---

# Comportamento Esperado

Para uma operação válida, o módulo deve:

1. permanecer disponível enquanto nenhuma operação estiver ativa;
2. aceitar `start` quando estiver livre;
3. registrar `a`, `b` e `op`;
4. bloquear novas transações enquanto a atual estiver em andamento;
5. direcionar ADD e SUB para `fpu_sum_sub`;
6. direcionar MUL para `fpu_mult_top`;
7. manter os operandos estáveis durante todo o processamento;
8. aguardar o sinal de conclusão do subsistema selecionado;
9. capturar o resultado correto;
10. selecionar as flags correspondentes;
11. fornecer GRS quando a operação for multiplicação;
12. fornecer GRS igual a zero para ADD e SUB;
13. ativar `done` quando `result` estiver válido;
14. liberar a FPU para uma nova operação após a conclusão.

A saída final mantém a estrutura:

```text
1 bit de sinal | 8 bits de expoente | 23 bits de mantissa
```

compatível com a organização utilizada pelo formato IEEE 754 de precisão
simples.
