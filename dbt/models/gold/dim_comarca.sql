-- GOLD | dim_comarca: dimensão de comarca.
--
-- Gold NÃO é "dados ainda mais limpos": é dado ORGANIZADO PARA O CONSUMO.
-- A pergunta de negócio ("tempo médio por comarca, classe e período")
-- pede um modelo dimensional: fato no centro, dimensões em volta.
--
-- Repare no ref(): ele não é um atalho para escrever nome de tabela.
-- Ele DECLARA que este modelo depende de stg_comarcas — e é assim
-- que o dbt monta a DAG do projeto.

select
    comarca_id,
    nome_comarca,
    uf
from {{ ref('stg_comarcas') }}
