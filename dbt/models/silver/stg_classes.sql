-- =====================================================================
-- SILVER | stg_classes
-- =====================================================================
-- DEDUPLICAÇÃO COM DECISÃO DE NEGÓCIO: este é o modelo mais
-- interessante da camada, porque o SQL sozinho não resolve o problema.
-- =====================================================================

{{ config(location='../data/silver/stg_classes.parquet') }}

with fonte as (

    select * from {{ source('bronze', 'classes') }}

),

classificada as (

    select
        cast(classe_id as integer) as classe_id,
        nome_classe,

        -- PROBLEMA: o MESMO classe_id (2) aparece duas vezes na origem,
        -- com grafias diferentes: "Execução Fiscal" e "EXECUCAO FISCAL".
        -- Se não tratarmos, a dim_classe fica com id duplicado e o join
        -- com a fato DUPLICA linhas (fan-out) — inflando as contagens.
        --
        -- COMO FUNCIONA: row_number() numera as linhas dentro de cada
        -- classe_id (partition by), numa ordem que nós escolhemos
        -- (order by). Ficamos com a nº 1.
        --
        -- ⚠ A REGRA ESCOLHIDA AQUI: preferir a grafia que NÃO está toda
        -- em maiúsculas — porque "Execução Fiscal" preserva acentuação
        -- e capitalização corretas.
        --
        -- MAS ATENÇÃO: essa é uma decisão ARBITRÁRIA que EU tomei.
        -- Numa organização real, "qual é a grafia oficial da classe
        -- processual?" é uma pergunta para quem é DONO desse dado —
        -- não para quem escreve o SQL. Este é o momento em que a
        -- governança aparece dentro de um modelo dbt.
        row_number() over (
            partition by cast(classe_id as integer)
            order by (nome_classe = upper(nome_classe)) asc
        ) as rn

    from fonte

)

select
    classe_id,
    nome_classe
from classificada
where rn = 1     -- fica só a linha escolhida por classe_id
