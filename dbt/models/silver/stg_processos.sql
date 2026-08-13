-- SILVER | stg_processos: tipagem e preparação lógica dos processos.
--
-- "stg_" aqui = modelo de PREPARAÇÃO LÓGICA (convenção dbt).
-- Não confundir com a staging area FÍSICA do ETL clássico:
-- lá era um lugar; aqui é uma transformação declarada em SQL.

{{ config(location='../data/silver/stg_processos.parquet') }}

with fonte as (

    select * from {{ source('bronze', 'processos') }}

)

select
    try_cast(processo_id as bigint)        as processo_id,
    try_cast(classe_id as integer)         as classe_id,
    try_cast(comarca_id as integer)        as comarca_id,
    try_cast(vara_id as integer)           as vara_id,

    -- try_cast: converte quando consegue; vira NULL quando não consegue.
    -- Pergunta importante: PARA ONDE FORAM os registros que viraram NULL?
    try_cast(data_distribuicao as date)    as data_distribuicao,
    -- TODO (em aula): algumas datas da origem estão em DD/MM/YYYY e o
    --   try_cast as transforma em NULL. Trate o formato alternativo:
    --   coalesce(try_cast(data_distribuicao as date),
    --            try_cast(try_strptime(data_distribuicao, '%d/%m/%Y') as date))

    try_cast(data_baixa as date)           as data_baixa,
    -- TODO (desafio): aplicar o mesmo tratamento de formato em data_baixa.

    situacao

from fonte

-- TODO (desafio): a origem contém linhas integralmente duplicadas.
--   Elimine as duplicatas (dica: select distinct resolve duplicata integral;
--   e se a duplicata fosse parcial — mesmo id, dados diferentes?).
