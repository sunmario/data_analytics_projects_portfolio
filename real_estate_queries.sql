/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Сорокина Мария
 * Дата: 20.07.2025
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Напишите ваш запрос здесь

WITH limits AS (
SELECT
    PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY total_area) AS total_area_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY rooms) AS rooms_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY balcony) AS balcony_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY ceiling_height) AS ceiling_height_limit_h,
    PERCENTILE_DISC(0.01) WITHIN GROUP (
    ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM
    real_estate.flats
),
filtered_id AS( SELECT id FROM real_estate.flats
WHERE total_area < (SELECT total_area_limit FROM limits) AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL) AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL) AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL) ),
categories_activity AS (
SELECT
    a.id,
    a.last_price / f.total_area AS cost_per_m,
    CASE
        WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'месяц'
        WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'квартал'
        WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'полгода'
        WHEN a.days_exposition > 181 THEN 'больше полугода'
        WHEN a.days_exposition IS NULL THEN 'объявление активно'
    END AS cat
FROM
    real_estate.advertisement AS a
INNER JOIN filtered_id AS fid using(id)
LEFT JOIN real_estate.flats AS f USING (id)
 )
SELECT
    CASE
        WHEN ct.city = 'Санкт-Петербург' THEN 'СПб'
        ELSE 'ЛенОбл'
    END AS region,
    c.cat AS segment,
    count(c.id) AS ads_cnt,
    round((COUNT(c.id) * 1.0 / SUM(COUNT(c.id)) OVER ()),2) AS ads_fraction,
    round(AVG(c.cost_per_m)::NUMERIC, 2) AS avg_price_per_sq_m,
    round(AVG(f.total_area)::NUMERIC, 2) AS avg_flat_area,
    COALESCE(round(AVG(f.balcony)), 0) AS avg_balcony_cnt,
    COALESCE(round(AVG(f.rooms)), 0) AS avg_room_cnt,
    round(AVG(f.ceiling_height)::NUMERIC, 2) AS avg_ceil_height,
    round(AVG(f.floor)::NUMERIC, 2) AS avg_floor
FROM
    categories_activity AS c
LEFT JOIN real_estate.flats AS f
        USING (id)
LEFT JOIN real_estate.city AS ct ON
    f.city_id = ct.city_id
LEFT JOIN real_estate.type AS t
        USING (type_id)
WHERE
    t.TYPE = 'город' AND c.cat <> 'объявление активно' AND c.cat IS NOT null
GROUP BY
    region,
    segment
ORDER BY
    region;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY total_area) AS total_area_limit, PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY rooms) AS rooms_limit, PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY balcony) AS balcony_limit, PERCENTILE_DISC(0.99) WITHIN GROUP (
    ORDER BY ceiling_height) AS ceiling_height_limit_h, PERCENTILE_DISC(0.01) WITHIN GROUP (
    ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats ), 
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE total_area < (
        SELECT total_area_limit
    FROM limits)
    AND (rooms < (
        SELECT rooms_limit
    FROM limits)
    OR rooms IS NULL)
    AND (balcony < (
        SELECT balcony_limit
    FROM limits)
    OR balcony IS NULL)
    AND ((ceiling_height < (
        SELECT ceiling_height_limit_h
    FROM limits)
    AND ceiling_height > (
        SELECT ceiling_height_limit_l
    FROM limits))
    OR ceiling_height IS NULL)), 
month_year_activity_publ AS (
    SELECT 
    EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)) AS year_publ, 
    EXTRACT(MONTH FROM CAST(first_day_exposition AS timestamp)) AS mon_publ, 
    COUNT(id) AS count_publ,
    round(AVG(a.last_price / f.total_area)::NUMERIC, 2) AS av_price_per_m_publ,
    round(AVG(f.total_area)::NUMERIC, 2) AS av_area_publ
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id AS fid using(id)
    LEFT JOIN real_estate.flats AS f USING (id)
    LEFT JOIN real_estate.TYPE AS t USING (type_id)
    WHERE EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)) <> 2019 
    AND EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)) <> 2014
    AND t.TYPE = 'город'
    GROUP BY EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)), EXTRACT(MONTH FROM CAST(first_day_exposition AS timestamp)) ), 
month_year_activity_del AS (
    SELECT 
    EXTRACT(YEAR FROM CAST(first_day_exposition + days_exposition * INTERVAL '1 day' AS timestamp)) AS year_del, 
    EXTRACT(MONTH FROM CAST(first_day_exposition + days_exposition * INTERVAL '1 day' AS timestamp)) AS mon_del, 
    COUNT(id) AS count_del,
    round(AVG(a.last_price / f.total_area)::NUMERIC, 2) AS av_price_per_m_del,
    round(AVG(f.total_area)::NUMERIC, 2) AS av_area_del
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id AS fid using(id)
    LEFT JOIN real_estate.flats AS f USING (id)
    LEFT JOIN real_estate.TYPE AS t USING (type_id)
    WHERE days_exposition IS NOT NULL AND EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)) <> 2019 
    AND EXTRACT(YEAR FROM CAST(first_day_exposition AS timestamp)) <> 2014
    AND t.TYPE = 'город'
    GROUP BY
        EXTRACT(YEAR FROM CAST(first_day_exposition + days_exposition * INTERVAL '1 day' AS timestamp)), 
        EXTRACT(MONTH FROM CAST(first_day_exposition + days_exposition * INTERVAL '1 day' AS timestamp)) ), 
del_stat AS (
    SELECT year_del, mon_del, count_del, av_price_per_m_del, av_area_del
    FROM(
        SELECT year_del, mon_del, count_del, av_price_per_m_del, av_area_del
    FROM month_year_activity_del
    ) AS subquery
    ORDER BY year_del,mon_del), 
pub_stat AS (
    SELECT year_publ, mon_publ, count_publ, av_price_per_m_publ, av_area_publ
    FROM(
        SELECT year_publ, mon_publ, count_publ, av_price_per_m_publ, av_area_publ
    FROM month_year_activity_publ
    ) AS subquery
    ORDER BY year_publ,mon_publ), 
total_act_stat AS (
    SELECT p.year_publ AS year_, p.mon_publ AS mon,
    p.count_publ,
    d.count_del,
    av_price_per_m_publ,
    av_price_per_m_del,
    av_area_publ, 
    av_area_del
    FROM pub_stat AS p
    FULL JOIN del_stat AS d ON p.year_publ = d.year_del and p.mon_publ = d.mon_del)
SELECT * FROM total_act_stat

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
top15_LO AS (
SELECT 
    c.city,
    count(id) AS cnt_flats,
    COUNT(a.id) FILTER (WHERE a.days_exposition IS NOT NULL) / COUNT(a.id) AS fraction_unpub,
    round(AVG(a.last_price / f.total_area)::NUMERIC, 2) AS av_price_per_m,
    round(AVG(f.total_area)::NUMERIC, 2) AS av_area,
    avg(a.days_exposition) AS av_act
FROM real_estate.flats AS f
INNER JOIN filtered_id AS fid using(id)
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.city AS c using(city_id)
WHERE city <> 'Санкт-Петербург'
GROUP BY city
HAVING count(id) >= 50
ORDER BY cnt_flats DESC)
SELECT * FROM top15_LO;


