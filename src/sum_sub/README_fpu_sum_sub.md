# FPU Sum/Sub — `fpu_sum_sub`

## Descrição Geral

O módulo `fpu_sum_sub` implementa a unidade funcional responsável pelas operações
de **soma** e **subtração** em ponto flutuante da FPU.

A arquitetura utiliza como referência o formato IEEE 754 de precisão simples,
no qual cada operando possui 32 bits divididos em três campos:

| Campo | Largura |
|---|---:|
| Sinal | 1 bit |
| Expoente | 8 bits |
| Mantissa | 23 bits |
| **Total** | **32 bits** |

Diferentemente de uma soma inteira convencional, a soma ou subtração de números
em ponto flutuante exige diversas etapas antes que as mantissas possam ser
operadas diretamente.

O módulo realiza, de forma sequencial:

- separação dos campos IEEE 754;
- reconstrução dos significandos;
- comparação dos expoentes;
- alinhamento das mantissas;
- soma ou subtração das magnitudes;
- determinação do sinal do resultado;
- normalização;
- arredondamento;
- reconstrução da palavra IEEE 754;
- geração dos sinais `done`, `overflow` e `underflow`.

O controle dessas etapas é realizado por uma máquina de estados finitos.

---

# Interface do Módulo

## Entradas

| Sinal | Largura | Descrição |
|---|---:|---|
| `clk` | 1 bit | Clock do circuito |
| `rst_n` | 1 bit | Reset assíncrono ativo em nível baixo |
| `start` | 1 bit | Solicita o início de uma nova operação |
| `op` | 2 bits | Seleciona soma ou subtração |
| `a` | 32 bits | Operando A em formato IEEE 754 de precisão simples |
| `b` | 32 bits | Operando B em formato IEEE 754 de precisão simples |

---

## Saídas

| Sinal | Largura | Descrição |
|---|---:|---|
| `result` | 32 bits | Resultado da operação em formato IEEE 754 |
| `done` | 1 bit | Indica a conclusão da operação |
| `overflow` | 1 bit | Indica condição de estouro da faixa do expoente |
| `underflow` | 1 bit | Indica condição associada ao limite inferior da faixa do expoente |

---

# Seleção da Operação

A entrada `op` determina qual operação deve ser realizada.

| `op` | Operação |
|---|---|
| `2'b00` | Soma |
| `2'b01` | Subtração |

Os demais códigos não fazem parte das operações definidas para este bloco.

Conceitualmente:

```text
op = 00 → A + B
op = 01 → A - B
```

---

# Organização dos Operandos

Cada entrada de 32 bits é separada nos campos:

```text
31          30                    23 22                     0
┌───────────┬──────────────────────┬────────────────────────┐
│   Sinal   │      Expoente        │       Mantissa         │
│   1 bit   │       8 bits         │        23 bits         │
└───────────┴──────────────────────┴────────────────────────┘
```

Para o operando A:

```text
a[31]    → sinal
a[30:23] → expoente
a[22:0]  → mantissa
```

Para o operando B:

```text
b[31]    → sinal
b[30:23] → expoente
b[22:0]  → mantissa
```

---

# Significando Interno

Para números normalizados no formato IEEE 754, o primeiro bit do significando é
implícito e possui valor `1`.

Assim, a mantissa armazenada:

```text
xxxxxxxxxxxxxxxxxxxxxxx
```

é interpretada internamente como:

```text
1.xxxxxxxxxxxxxxxxxxxxxxx
```

O módulo reconstrói esse bit antes da execução da operação aritmética.

---

# Estrutura Interna da Mantissa

As mantissas são ampliadas internamente para 28 bits.

A organização utilizada é:

```text
27      26       25                       3   2   1   0
┌───────┬────────┬─────────────────────────┬───┬───┬───┐
│ OVF   │ Hidden │        Fraction         │ G │ R │ S │
└───────┴────────┴─────────────────────────┴───┴───┴───┘
```

onde:

| Campo | Função |
|---|---|
| `mant_[27]` | Bit adicional para detectar carry/overflow da mantissa |
| `mant_[26]` | Bit implícito do significando normalizado |
| `mant_[25:3]` | Fração de 23 bits |
| `mant_[2]` | Guard |
| `mant_[1]` | Round |
| `mant_[0]` | Posição de menor peso associada à precisão intermediária |

Na reconstrução inicial, os três bits menos significativos são inicializados em
zero.

Assim, cada operando passa da forma:

```text
1.mantissa
```

para uma representação intermediária que reserva posições adicionais para o
processamento de alinhamento e arredondamento.

---

# Organização Geral da Arquitetura

O fluxo de dados do módulo pode ser representado de forma simplificada por:

```text
                    A[31:0]                     B[31:0]
                       │                           │
                       ▼                           ▼
                ┌────────────┐              ┌────────────┐
                │  UNPACK A  │              │  UNPACK B  │
                └─────┬──────┘              └─────┬──────┘
                      │                           │
                      ├────────────┬──────────────┤
                      │            │              │
                      ▼            ▼              ▼
                    Sinal       Expoente       Mantissa
                      │            │              │
                      │            ▼              │
                      │      ┌────────────┐        │
                      │      │   ALIGN    │◄───────┘
                      │      └─────┬──────┘
                      │            │
                      │            ▼
                      │      ┌────────────┐
                      └─────►│  EXECUTE   │
                             └─────┬──────┘
                                   │
                                   ▼
                             ┌────────────┐
                             │ NORMALIZE  │
                             └─────┬──────┘
                                   │
                                   ▼
                             ┌────────────┐
                             │   ROUND    │
                             └─────┬──────┘
                                   │
                                   ▼
                             ┌────────────┐
                             │   FINISH   │
                             └─────┬──────┘
                                   │
                                   ▼
                              result[31:0]
```

---

# Máquina de Estados

O processamento é controlado por uma FSM composta por sete estados:

| Estado | Código | Função |
|---|---|---|
| `IDLE` | `000` | Aguarda uma nova operação |
| `UNPACK` | `001` | Separa e prepara os campos dos operandos |
| `ALIGN` | `010` | Alinha as mantissas de acordo com os expoentes |
| `EXECUTE` | `011` | Realiza a soma ou subtração das mantissas |
| `NORMALIZE` | `100` | Normaliza a mantissa resultante |
| `ROUND` | `101` | Executa o arredondamento |
| `FINISH` | `110` | Monta o resultado e sinaliza a conclusão |

A FSM retorna para `IDLE` após `FINISH`.

---

# 1. Estado `IDLE`

O estado `IDLE` representa a condição de repouso da unidade.

Enquanto:

```text
start = 0
```

o módulo permanece nesse estado.

Quando:

```text
start = 1
```

uma nova operação é aceita e a FSM inicia o processamento.

Nesse estado, `done` é mantido em zero.

---

# 2. Estado `UNPACK`

O estado `UNPACK` separa os campos IEEE 754 dos operandos.

Para cada entrada são armazenados internamente:

- sinal;
- expoente;
- mantissa.

Também é reconstruído o bit implícito `1` das mantissas normalizadas.

A representação interna passa a conter:

```text
overflow bit | hidden bit | fraction | GRS
```

permitindo que as etapas seguintes trabalhem com precisão adicional.

O bit Sticky auxiliar também é inicializado em zero no início da operação.

---

# 3. Estado `ALIGN`

## Necessidade de alinhamento

Para que dois números em ponto flutuante possam ser somados ou subtraídos, seus
significandos precisam representar a mesma potência de dois.

Considere:

```text
A = MA × 2^EA
B = MB × 2^EB
```

Se:

```text
EA != EB
```

as mantissas não podem ser operadas diretamente.

O operando com menor expoente precisa ter sua mantissa deslocada para a direita
até que ambos os expoentes sejam equivalentes.

---

## Comparação dos expoentes

Existem três possibilidades.

### `exp_a > exp_b`

O expoente de A é adotado como expoente de referência:

```text
exp_res = exp_a
```

A diferença é:

```text
exp_diff = exp_a - exp_b
```

e a mantissa de B é deslocada para a direita.

---

### `exp_a < exp_b`

O expoente de B passa a ser a referência:

```text
exp_res = exp_b
```

A diferença é:

```text
exp_diff = exp_b - exp_a
```

e a mantissa de A é deslocada para a direita.

---

### `exp_a == exp_b`

Nenhuma mantissa precisa ser deslocada.

O expoente comum é utilizado diretamente:

```text
exp_res = exp_a
```

---

# Deslocamento com Sticky

O alinhamento utiliza uma função específica para deslocamento à direita com
preservação da informação dos bits descartados.

A função considera três situações.

## Sem deslocamento

Quando:

```text
shift_amount = 0
```

a mantissa permanece inalterada e o Sticky é zero.

---

## Deslocamento parcial

Quando o deslocamento é menor que a largura da mantissa, a mantissa é deslocada
para a direita e todos os bits descartados são examinados.

Se pelo menos um deles possuir valor `1`:

```text
sticky = 1
```

Caso todos os bits descartados sejam zero:

```text
sticky = 0
```

---

## Deslocamento total

Quando a diferença de expoentes é maior ou igual à largura da mantissa
intermediária, o valor deslocado torna-se zero.

Entretanto, a informação de que existiam bits não nulos não é completamente
perdida.

Nesse caso:

```text
sticky = OR de todos os bits da mantissa original
```

---

# Função do Sticky

O Sticky preserva informação sobre bits que desapareceram durante o alinhamento.

Isso é importante porque a parte descartada ainda influencia a precisão do
resultado.

De forma conceitual:

```text
bits descartados = 000000...
→ sticky = 0
```

```text
bits descartados = 000100...
→ sticky = 1
```

A implementação mantém essa informação em um sinal auxiliar denominado
`sticky_bit`, utilizado durante o processamento da mantissa.

---

# 4. Estado `EXECUTE`

Após o alinhamento, as mantissas representam a mesma escala e podem ser
operadas.

A operação efetivamente realizada depende de:

- `op`;
- sinal de A;
- sinal de B;
- magnitude das mantissas.

Isso ocorre porque uma soma de números com sinais diferentes equivale a uma
subtração das magnitudes, enquanto uma subtração entre sinais diferentes pode
equivaler a uma soma das magnitudes.

---

# Soma — `op = 00`

## Sinais iguais

Quando A e B possuem o mesmo sinal:

```text
(+A) + (+B)
```

ou:

```text
(-A) + (-B)
```

as magnitudes são somadas.

O sinal do resultado é mantido igual ao sinal dos operandos.

Conceitualmente:

```text
mant_res = mant_a + mant_b
sign_res = sign_a
```

---

## Sinais diferentes

Quando os sinais são diferentes:

```text
(+A) + (-B)
```

ou:

```text
(-A) + (+B)
```

a operação entre as magnitudes é uma subtração.

A maior magnitude determina o sinal do resultado.

---

# Subtração — `op = 01`

## Sinais diferentes

Quando os operandos possuem sinais diferentes:

```text
(+A) - (-B)
```

ou:

```text
(-A) - (+B)
```

a operação equivale à soma das magnitudes.

O sinal é determinado pelo operando A.

---

## Sinais iguais

Quando os sinais são iguais:

```text
(+A) - (+B)
```

ou:

```text
(-A) - (-B)
```

as magnitudes são subtraídas.

O módulo compara as mantissas para determinar qual magnitude é maior e, a
partir disso, define o sinal correto do resultado.

---

# Determinação do Sinal

A determinação do sinal não é realizada por uma única operação lógica.

Ela depende da operação e das magnitudes.

De forma resumida:

| Operação | Relação entre sinais | Operação nas mantissas |
|---|---|---|
| Soma | Iguais | Soma |
| Soma | Diferentes | Subtração |
| Subtração | Iguais | Subtração |
| Subtração | Diferentes | Soma |

Quando ocorre uma subtração de magnitudes, a maior mantissa determina a
polaridade do resultado.

---

# Cancelamento Exato

Quando duas magnitudes iguais se anulam, o resultado da mantissa torna-se zero.

Exemplos:

```text
A + (-A) = 0
```

e:

```text
A - A = 0
```

Nessa condição, o módulo força o resultado final para:

```text
+0.0
```

representado por:

```text
0x00000000
```

Dessa forma, o zero produzido por cancelamento é sempre positivo.

---

# 5. Estado `NORMALIZE`

Após a soma ou subtração das mantissas, o resultado pode não estar na forma
normalizada esperada.

O objetivo desta etapa é restaurar a estrutura:

```text
1.xxxxxxxxxxxxxxxxxxxxxxx
```

e ajustar o expoente de acordo com os deslocamentos realizados.

---

## Carry após uma soma

Uma soma pode gerar um bit adicional:

```text
1.xxxxx
+
1.xxxxx
---------
10.xxxxx
```

Nesse caso, o bit de overflow da mantissa é ativado.

A mantissa é deslocada uma posição para a direita:

```text
10.xxxxx
→
1.xxxxx
```

Como esse deslocamento representa uma multiplicação da escala por dois, o
expoente é incrementado:

```text
exp_res = exp_res + 1
```

---

## Cancelamento parcial após uma subtração

Uma subtração pode produzir:

```text
0.001xxxxx
```

Nesse caso, o bit implícito esperado não está na posição correta.

A mantissa é deslocada para a esquerda até que o primeiro `1` alcance a posição
do hidden bit.

A cada deslocamento:

```text
mantissa << 1
```

o expoente é decrementado:

```text
exp_res = exp_res - 1
```

Esse processo pode exigir vários ciclos.

Por isso, o estado `NORMALIZE` pode permanecer ativo por mais de um ciclo.

---

## Resultado zero

Se:

```text
mant_res = 0
```

não existe significando a normalizar.

A FSM segue para a etapa de arredondamento/finalização.

---

# Latência Variável

A quantidade de ciclos necessária para uma operação não é necessariamente
constante.

A maior parte das etapas utiliza um ciclo de processamento, porém a
normalização após uma subtração pode exigir vários deslocamentos à esquerda.

Consequentemente:

- resultados já normalizados terminam mais rapidamente;
- resultados que exigem vários deslocamentos permanecem mais tempo em
  `NORMALIZE`.

O sinal `done` deve ser utilizado como referência para identificar a conclusão
da operação.

---

# 6. Estado `ROUND`

Após a normalização, o módulo executa a etapa de arredondamento.

A implementação utiliza o bit Guard:

```text
mant_res[2]
```

como condição de arredondamento.

Quando:

```text
Guard = 1
```

é adicionada uma unidade à posição imediatamente acima dos bits auxiliares:

```text
mant_res = mant_res + 8
```

Esse comportamento corresponde à política de arredondamento utilizada pelo
bloco, baseada em arredondamento para cima quando o bit Guard é igual a `1`.

---

# Carry Gerado pelo Arredondamento

O arredondamento pode transformar uma mantissa próxima do limite em um valor com
carry adicional.

Conceitualmente:

```text
1.111111...
+
0.000001...
------------
10.000000...
```

Quando isso ocorre, a montagem final considera o bit adicional e incrementa o
expoente para preservar o valor numérico.

---

# 7. Estado `FINISH`

O estado `FINISH` monta a palavra de saída e encerra a operação.

O resultado é reconstruído no formato:

```text
Sinal | Expoente | Mantissa
```

com 32 bits.

---

## Resultado não nulo

Para uma mantissa normalizada convencional, a palavra é formada por:

```text
sign_res
exp_res
mantissa final de 23 bits
```

O hidden bit não é armazenado, pois permanece implícito na representação
IEEE 754.

---

## Carry final

Caso ainda exista um bit adicional de carry na mantissa, a seleção dos bits é
ajustada e o expoente recebe um incremento.

---

## Resultado zero

Quando a mantissa final é zero:

```text
result = 0x00000000
```

forçando a representação:

```text
+0.0
```

---

# Sinal `done`

Durante `FINISH`:

```text
done = 1
```

indicando que `result` contém o valor final da operação.

Na sequência, a FSM retorna para `IDLE`, onde:

```text
done = 0
```

Portanto, `done` funciona como indicação de conclusão da operação e deve ser
utilizado pela lógica externa ou pela bancada de verificação para determinar
quando o resultado pode ser avaliado.

---

# Overflow

O sinal `overflow` é atualizado durante a finalização da operação.

A implementação verifica a condição do expoente de resultado e sinaliza
overflow quando ele alcança:

```text
8'hFF
```

Esse valor corresponde ao campo de expoente reservado no formato IEEE 754 para
representações especiais.

O sinal permite que uma lógica externa identifique que o resultado atingiu o
limite superior tratado pelo bloco.

---

# Underflow

O sinal `underflow` também é atualizado durante `FINISH`.

A implementação sinaliza a condição quando:

```text
exp_res = 0
```

Essa condição representa o limite inferior do expoente tratado pelo datapath.

O tratamento completo de números subnormais pode exigir lógica adicional
específica.

---

# Fluxo Completo da Operação

O processamento pode ser resumido nas seguintes etapas.

## Etapa 1 — Início

A unidade permanece em `IDLE` até:

```text
start = 1
```

---

## Etapa 2 — Separação dos campos

Os operandos são divididos em:

```text
Sinal
Expoente
Mantissa
```

e os significandos internos são reconstruídos.

---

## Etapa 3 — Comparação dos expoentes

Os expoentes são comparados para determinar qual operando possui maior escala.

---

## Etapa 4 — Alinhamento

A mantissa associada ao menor expoente é deslocada para a direita.

Os bits descartados contribuem para a geração do Sticky.

---

## Etapa 5 — Operação aritmética

De acordo com `op` e com os sinais dos operandos, o módulo executa:

```text
mant_a + mant_b
```

ou:

```text
mant_a - mant_b
```

A magnitude dos operandos também é considerada para determinar o sinal final.

---

## Etapa 6 — Normalização

A mantissa é ajustada para restaurar o hidden bit na posição correta.

Quando necessário, o expoente é incrementado ou decrementado.

---

## Etapa 7 — Arredondamento

O bit Guard é analisado.

Quando está em `1`, a mantissa é incrementada na posição correspondente ao bit
menos significativo mantido no resultado.

---

## Etapa 8 — Formação da palavra final

O módulo concatena:

```text
sinal | expoente | mantissa
```

e produz `result[31:0]`.

---

## Etapa 9 — Finalização

Os sinais:

```text
done
overflow
underflow
```

são atualizados e a máquina retorna para `IDLE`.

---

# Exemplo Conceitual — Soma com Expoentes Diferentes

Considere:

```text
1.0 + 0.5
```

Em binário normalizado:

```text
1.0 = 1.0 × 2^0
0.5 = 1.0 × 2^-1
```

Os expoentes são diferentes.

Antes da soma, o segundo significando precisa ser alinhado:

```text
1.0 × 2^0
0.1 × 2^0
```

Agora as mantissas podem ser somadas:

```text
1.0
+
0.1
---
1.1
```

resultando em:

```text
1.1₂ = 1.5
```

---

# Exemplo Conceitual — Soma com Carry

Considere:

```text
1.5 + 1.5
```

Os significandos são:

```text
1.1₂
+
1.1₂
-----
11.0₂
```

O resultado possui um bit adicional.

A normalização transforma:

```text
11.0₂ × 2^0
```

em:

```text
1.10₂ × 2^1
```

Portanto, além do deslocamento da mantissa, o expoente precisa ser
incrementado.

O resultado final é:

```text
3.0
```

---

# Exemplo Conceitual — Subtração com Normalização à Esquerda

Considere duas magnitudes próximas:

```text
1.0 - 0.75
```

Após o alinhamento e a subtração, o significando resultante pode apresentar
zeros à esquerda.

O normalizador desloca a mantissa para a esquerda até restaurar a forma:

```text
1.xxxxx
```

A cada deslocamento, o expoente é decrementado.

Esse comportamento permite representar corretamente resultados menores
produzidos pelo cancelamento parcial das duas magnitudes.

---

# Características do Bloco

A unidade possui as seguintes características principais:

- operandos de 32 bits;
- estrutura baseada no formato IEEE 754 de precisão simples;
- soma e subtração selecionadas por `op`;
- execução sequencial controlada por FSM;
- alinhamento automático de expoentes;
- preservação de informação Sticky durante deslocamentos;
- operação sobre mantissas estendidas;
- normalização para a direita em caso de carry;
- normalização iterativa para a esquerda após cancelamento;
- arredondamento baseado no bit Guard;
- resultado de 32 bits;
- sinalização de conclusão por `done`;
- sinalização de `overflow` e `underflow`.

---

# Considerações sobre o Formato IEEE 754

A arquitetura utiliza a organização de campos da precisão simples e implementa
as etapas fundamentais necessárias para soma e subtração em ponto flutuante.

Entretanto, o datapath apresentado concentra-se no processamento de números
normalizados.

Na reconstrução das mantissas, o hidden bit é inserido diretamente como `1`.
Por esse motivo, operandos subnormais, zeros de entrada, infinitos e NaNs
exigem tratamento específico caso se deseje cobertura completa de todos os
casos especiais definidos pelo padrão IEEE 754.

Da mesma forma, a política de arredondamento implementada utiliza o bit Guard
como critério direto para incremento da mantissa. Ela deve ser entendida como a
política de arredondamento própria deste bloco, e não como uma implementação
completa de todos os modos de arredondamento definidos pelo IEEE 754.

---

# Arquivo Relacionado

| Arquivo | Função |
|---|---|
| `fpu_sum_sub.v` | Implementa o datapath e a máquina de estados das operações de soma e subtração em ponto flutuante |

---

# Resumo dos Subsistemas

| Subsistema | Função |
|---|---|
| Extração IEEE 754 | Separa sinal, expoente e mantissa dos operandos |
| Reconstrução do significando | Insere o hidden bit e reserva bits auxiliares |
| Controle FSM | Coordena sequencialmente todas as etapas |
| Alinhamento | Igualiza os expoentes através de deslocamento da menor mantissa |
| Sticky | Preserva informação dos bits descartados no alinhamento |
| Execução aritmética | Realiza soma ou subtração das magnitudes |
| Lógica de sinal | Determina a polaridade correta do resultado |
| Normalização | Reposiciona o hidden bit e corrige o expoente |
| Arredondamento | Ajusta a mantissa com base no Guard |
| Finalização | Reconstrói o resultado IEEE 754 e gera as flags |

---

# Comportamento Esperado

Para uma operação válida, o módulo deve:

1. permanecer em `IDLE` enquanto `start` estiver desativado;
2. iniciar o processamento quando `start` for ativado;
3. separar os campos IEEE 754 dos dois operandos;
4. reconstruir os significandos internos;
5. comparar os expoentes;
6. deslocar a mantissa associada ao menor expoente;
7. preservar informação dos bits descartados através do Sticky;
8. decidir entre soma e subtração de magnitudes com base em `op` e nos sinais;
9. determinar o sinal do resultado;
10. normalizar a mantissa;
11. corrigir o expoente conforme os deslocamentos de normalização;
12. aplicar o arredondamento;
13. reconstruir a palavra de 32 bits;
14. atualizar `overflow` e `underflow`;
15. ativar `done` quando `result` estiver disponível;
16. retornar ao estado `IDLE` para aguardar uma nova operação.

A estrutura final de `result` é:

```text
1 bit de sinal | 8 bits de expoente | 23 bits de mantissa
```

mantendo a organização utilizada pelo formato IEEE 754 de precisão simples.
