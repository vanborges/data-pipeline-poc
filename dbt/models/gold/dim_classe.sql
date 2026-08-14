-- =====================================================================
-- GOLD | dim_classe — DIMENSÃO
-- =====================================================================
-- Também conformed: servirá qualquer fato que precise da perspectiva
-- "classe processual".
--
-- ⚠ Repare de onde ela vem: stg_classes, que resolveu a duplicação de
-- classe_id. Se aquele problema não tivesse sido tratado na Silver,
-- ele CONTAMINARIA esta dimensão — e o join com a fato duplicaria
-- linhas, inflando todas as contagens.
--
-- Moral: problema não tratado na Silver não fica na Silver.
-- =====================================================================

{{ config(location='../data/gold/dim_classe.parquet') }}

select
    classe_id,
    nome_classe
from {{ ref('stg_classes') }}
