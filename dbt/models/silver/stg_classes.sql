-- SILVER | stg_classes: padronização e deduplicação das classes processuais.

with fonte as (

    select * from {{ source('bronze', 'classes') }}

)

select
    cast(classe_id as integer) as classe_id,
    nome_classe

from fonte

-- TODO (desafio): a origem traz o MESMO classe_id repetido com grafias
--   diferentes ("Execução Fiscal" e "EXECUCAO FISCAL").
--   1) Escolha uma regra para ficar com UMA linha por classe_id
--      (dica: row_number() over (partition by classe_id order by ...) = 1).
--   2) Padronize a grafia escolhida.
--   Repare: essa é uma DECISÃO sobre o dado, não só um comando —
--   qual grafia é a "oficial"? Quem decide isso? (governança!)
