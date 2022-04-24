# DEISI258 - Modelamento multi-agente de interações em grupos sociais

Aluno: Paulo Pinto a21906966

Orientador: Manuel Marques Pita

Para esta entrega, há duas componentes:

- A simulação desenvolvida em NetLogo
- O conector em Python (Novo)

## NetLogo

A simulação foi alterada de modo a que os agentes passassem a interagir com uma *board* central, em vez de entre si.

A interação funciona da seguinte maneira:

1. A board é inicializada com uma *Knowledge Unit* - KU
2. Os agentes trocam o foco (como faziam anteriormente)
3. Cada agente adiciona à board a sua KU em foco, se esta for compatível com qualquer uma na board
4. A board fica apenas com as KUs adicionadas neste tick e volta para o passo 2

## Python

O conector em Python `pynetlogo_ku.ipynb` corre a simulação e obtém dados da mesma, abrindo a possibilidade de fazer uma
análise dos dados mais aprofundada. O ficheiro está preparado de forma a que as células possam ser executadas em ordem
sem haver problemas.

## Instruções de utilização

Para correr a simulação em si, só é necessário [instalar o NetLogo](https://ccl.northwestern.edu/netlogo/download.shtml)
(versão 6.2, para bater certo com o conector Python)
e abrir o ficheiro [knowledge_units_with_board.nlogo](files/knowledge_units_with_board.nlogo) na aplicação.

Para correr o [notebook](pynetlogo_ku.ipynb), há várias opções:

- IDEs como o PyCharm ou o VSCode já têm plugins ou mesmo a funcionalidade built-in de trabalhar com este tipo de
  ficheiros (criar/alterar/executar)
- Instalar o [Jupyter Notebooks](https://jupyter.org/install), para executar o ficheiro localmente no browser

Também é necessário [instalar o Python](https://www.python.org/downloads/) (foi utilizada a versão 3.10.4, em princípio
a partir da versão 3.8 funciona) e adicionar o endereço da instalação do NetLogo às Variáveis de Ambiente da máquina.

## Demonstração Video

[![Demonstração](https://i9.ytimg.com/vi_webp/0aawaW1K_t8/mqdefault.webp?v=62655fb3&sqp=CKjjlZMG&rs=AOn4CLCHK7_oIc8Q2yOOSKfxTLzwnzMH7Q)](https://youtu.be/0aawaW1K_t8)
