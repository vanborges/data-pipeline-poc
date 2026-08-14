-- =====================================================================
-- GOLD | fato_processo — a TABELA FATO do modelo dimensional
-- =====================================================================
-- GRÃO: uma linha = um processo.
--
-- O grão é a decisão mais importante da modelagem dimensional, e por
-- isso é declarado antes de qualquer coisa. Ele responde: "o que
-- representa UMA linha desta tabela?"
--
-- ⚠ Consequência prática: se alguém juntar esta fato com movimentações
-- (que estão no grão de EVENTO), cada processo vira várias linhas e as
-- médias se corrompem. Isso se chama FAN-OUT e é o erro nº 1 com fatos.
--
-- ANATOMIA DE UMA FATO — só três tipos de coluna:
--   1. chaves para as dimensões (comarca_id, classe_id, datas)
--   2. dimensões degeneradas (processo_id, vara_id)
--   3. MEDIDAS (tempo_tramitacao_dias)
-- Atributo descritivo (como nome_comarca) NÃO entra: é da dimensão.
--
-- TIPO DE FATO: esta é um "accumulating snapshot" — guarda marcos do
-- ciclo de vida (distribuição e baixa) e a linha é ATUALIZADA quando o
-- processo baixa. Um fato de movimentações seria "transactional"
-- (só insere, nunca atualiza).
-- =====================================================================

{{ config(location='../data/gold/fato_processo.parquet') }}

with processos as (

    -- ref() declara a dependência: este modelo só pode ser construído
    -- DEPOIS de stg_processos. Ninguém escreve essa ordem em lugar
    -- nenhum — o dbt a deduz dos ref() e monta a DAG do projeto.
    select * from {{ ref('stg_processos') }}

)

select
    p.processo_id,          -- dimensão degenerada (identificador)
    p.comarca_id,           -- FK -> dim_comarca
    p.classe_id,            -- FK -> dim_classe

    -- vara_id é uma DIMENSÃO DEGENERADA: fica na própria fato porque a
    -- origem só nos dá o identificador, sem nome nem atributos — não há
    -- o que colocar numa dim_vara. Se chegasse um cadastro de varas
    -- (nome, competência, magistrado), aí sim valeria uma dimensão.
    --
    -- ⚠ ATENÇÃO ao analisar: vara_id NÃO é único no estado — a "vara 2"
    -- existe em várias comarcas. Agrupar só por vara_id mistura varas
    -- diferentes. A identificação real é o par (comarca_id, vara_id).
    p.vara_id,

    -- as duas datas são chaves para a MESMA dim_tempo, em papéis
    -- diferentes: isso se chama ROLE-PLAYING DIMENSION.
    -- Consequência: "processos distribuídos em 2024" e "processos
    -- baixados em 2024" são perguntas diferentes, com joins diferentes.
    p.data_distribuicao,
    p.data_baixa,

    p.situacao,

    -- =================================================================
    -- A MEDIDA — o número que o negócio quer analisar
    -- =================================================================
    -- Ela NÃO existe em fonte nenhuma: é DERIVADA de dois marcos.
    -- É aqui que "dado" vira "informação".
    --
    -- Duas decisões de negócio embutidas neste CASE:
    --
    -- 1) Processos EM ANDAMENTO (sem data_baixa) ficam com medida NULA.
    --    Ou seja: não entram nas médias. É uma decisão consciente —
    --    incluí-los como "tempo até hoje" daria outro número, também
    --    defensável. O importante é que a decisão esteja documentada
    --    e valha para todos, e não escondida na consulta de cada um.
    --
    -- 2) Tempo NEGATIVO (baixa anterior à distribuição) também vira
    --    NULO. É dado implausível vindo da origem. Note a diferença:
    --    aqui nós protegemos a métrica, mas o problema continua lá.
    --    Quem avisa a origem? Isso é gestão de dados, não SQL.
    --
    -- ⚠ Por que guardamos a medida POR PROCESSO e não a média já
    -- calculada? Porque MÉDIA NÃO É ADITIVA: média de médias não é a
    -- média. Guardando no grão, é possível agregar por qualquer
    -- combinação de dimensões depois.
    case
        when p.data_baixa is not null
         and p.data_baixa >= p.data_distribuicao
        then date_diff('day', p.data_distribuicao, p.data_baixa)
    end as tempo_tramitacao_dias

from processos p

-- INTEGRIDADE REFERENCIAL: a origem tem um processo apontando para uma
-- comarca que não existe no cadastro (comarca_id = 99).
--
-- Em um banco relacional, a chave estrangeira IMPEDIRIA essa gravação.
-- Em arquivos Parquet não existe FK — então a proteção vira código
-- (este filtro) mais um TESTE que acusa o problema (ver schema.yml).
--
-- ⚠ ALTERNATIVA MAIS MADURA: em vez de descartar, apontar o registro
-- para uma linha "Não informado" na dimensão (a clássica sk = 0).
-- Assim o processo apareceria no relatório como "Não informado" em vez
-- de sumir silenciosamente. Sumir com o dado problemático é sempre a
-- opção mais perigosa.
where p.comarca_id in (select comarca_id from {{ ref('stg_comarcas') }})
