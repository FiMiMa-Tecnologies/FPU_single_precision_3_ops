# FPU_single_precision_3_ops
A simple float point unity, with 3 operations: Add, Sub &amp; Mult.

# Pasta para salvarmos nossas literaturas de referência e materiais de base:
https://drive.google.com/drive/folders/1QedroFW9vwhVdcNoDf_pnGiU2PG0np_F

# Padronização de branchs:

FEAT-NOME_PESSOA-A_FAZER-SUB_BLOCO

Ex:
FEAT-MATHEUS-RTL-MULT

# Padronização de nomes de sub-blocos:

fpu_NOME_SUB_BLOCO.v

Ex:
fpu_mult.v

# Padronização de nomes de READMEs de sub-blocos:

README_fpu_NOME_SUB_BLOCO.v

Ex:
README_fpu_mult.md


# Padronização da nomenclatura dos sinais de entrada:
A_s = Sinal de A
A_m = Mantissa de A
A_e = Expoente de A

B_s = Sinal de B
B_m = Mantissa de B
B_e = Expoente de B

# Árvore inicial do projeto:

├── diagrams
│   └── insira_aqui
├── docs
│   └── insira_aqui
├── images
│   └── insira_aqui
├── makefiles
│   └── insira_aqui
├── README.md
├── scripts
│   └── insira_aqui
└── src
    └── multiplier
        ├── multiplier.v
        └── referencia_de_projeto.jpg
        └── README_fpu_mult.md
