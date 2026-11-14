# ULA de 4bits SD-Peter-Cross

**Trabalho 1 – Sistemas Digitais (EEL 480) · Prof. Pedro Cruz**

Unidade lógica e aritmética (ULA) de 4 bits com 8 operações, escrita em VHDL para o kit Xilinx Spartan-3A/3AN. Toda a entrada de dados é feita com **apenas 4 switches e 1 botão de confirmação**: o usuário informa a operação, o operando A e o operando B, em sequência, e o resultado e as flags aparecem nos 8 LEDs da placa (4 bits de resultado + 4 flags).

## Visão geral

- Entrada sequencial por uma única porta, controlada por uma **FSM de 3 estados** (`S_OP → S_A → S_B`) que avança a cada aperto do botão.
- Botão tratado por um **debouncer** (sincronizador de 2 flip-flops + filtro de 20 ms) e por um **detector de borda**, garantindo um único avanço da FSM por aperto.
- Botão de reset passa por um **sincronizador de 2 flip-flops**.
- Saídas registradas: o resultado e as flags permanecem nos LEDs até o próximo cálculo.

## Operações

| Código | Operação | Resultado | Cout | Overflow |
|:------:|----------|-----------|:----:|:--------:|
| `0000` | A + B (com sinal) | 4 bits menos significativos da soma | carry sem sinal | estouro em compl. a 2 |
| `0001` | A − B (com sinal) | 4 bits menos significativos da diferença | borrow (A < B sem sinal) | estouro em compl. a 2 |
| `0010` | A OR B | OU bit a bit | 0 | 0 |
| `0011` | A AND B | E bit a bit | 0 | 0 |
| `0100` | A + 1 (B ignorado) | incremento com sinal (+7 vira −8) | 0 | 1 se A = `0111` |
| `0101` | A < B (sem sinal) | `1111` se verdadeiro, `0000` se falso | 0 | 0 |
| `0110` | A XOR B | OU exclusivo bit a bit | 0 | 0 |
| `0111` | A > B (sem sinal) | `1111` se verdadeiro, `0000` se falso | 0 | 0 |
| `1000`–`1111` | Não definidas | `0000` | 0 | 0 |

### Flags

- **Zero**: 1 quando o resultado é `0000`.
- **Negative**: bit 3 do resultado; forçado a 0 nas comparações (`1111` significa "verdadeiro", não um número negativo).
- **Cout**: carry da soma; **borrow** na subtração (convenção adotada neste projeto).
- **Overflow**: estouro da faixa de −8 a +7 em soma, subtração e incremento.

## Como usar

1. Ajuste os switches com o **código da operação** e aperte `BTN_EAST`.
2. Ajuste os switches com o **operando A** e aperte `BTN_EAST`.
3. Ajuste os switches com o **operando B** e aperte `BTN_EAST`.
4. O resultado e as flags aparecem nos LEDs e ficam até o próximo cálculo.

`BTN_WEST` (reset) volta ao passo 1 e zera registradores e saídas.

## Mapeamento da placa

| Sinal | Elemento | Pino |
|-------|----------|------|
| `clk` | Clock 50 MHz | E12 |
| `input<0..3>` | SW0, SW1, SW2, SW3 | V8, U10, U8, T9 |
| `button` | BTN_EAST (confirma) | T16 |
| `reset` | BTN_WEST | U15 |
| `output<0..3>` | LED0 a LED3 | R20, T19, U20, U19 |
| `zero` | LED4 | V19 |
| `negative` | LED5 | V20 |
| `cout` | LED6 | Y22 |
| `overflow` | LED7 | W21 |

Pinos obtidos do guia da placa (Xilinx UG334).

## Arquitetura

| Bloco | Função |
|-------|--------|
| Debouncer | Sincroniza o botão ao clock e filtra o bouncing |
| Detector de borda | Gera um pulso de um ciclo por aperto |
| Sincronizador de reset | Dois flip-flops em série |
| FSM | Controla a sequência op → A → B e guarda os valores em registradores |
| ULA | Executa a operação em `operation_reg` e gera resultado e flags |

## Estrutura do repositório

| Arquivo | Descrição |
|---------|-----------|
| `ULA_SD.vhd` | Entidade principal: FSM, registradores e lógica da ULA |
| `Debouncer.vhd` | Condicionamento do botão (sincronização + filtro de estabilidade) |

## Limitações

- A placa não indica em qual passo (operação, A ou B) o sistema está, pois os 8 LEDs são usados para resultado e flags.
- Convenções adotadas: borrow na subtração, negative forçado a 0 nas comparações e saída `0000` para códigos não definidos.
- A arquitetura pode ser estendida para operandos maiores (8 ou 16 bits) mantendo a mesma FSM e o mesmo debounce.
