-- GOLD | dim_classe: dimensão de classe processual.

select
    classe_id,
    nome_classe
from {{ ref('stg_classes') }}

-- Enquanto o TODO de deduplicação da stg_classes não for resolvido,
-- esta dimensão herda o problema (classe_id repetido).
-- Moral: problema não tratado na Silver CONTAMINA a Gold.
