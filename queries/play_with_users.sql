SELECT
    p.userId,
    p.activityId,
    p."ชื่อกิจกรรม" as activity_name,
    p."ประเภท" as activity_type,
    TRY_STRPTIME(REPLACE(p."เริ่มเล่นเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') as started_at,
    TRY_STRPTIME(REPLACE(p."เล่นจบเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') as finished_at,
    NULLIF(TRY_CAST(u."อายุ" AS INTEGER), 1) as age,
    NULLIF(NULLIF(TRIM(u."อาชีพ"), ''), '-') as occupation,
    NULLIF(NULLIF(TRIM(u."สังกัด"), 'null'), '-') as affiliation,
    u."ชื่อเล่น" as nickname
FROM play_results p
LEFT JOIN users u
    ON p.userId = u.userId
WHERE TRY_STRPTIME(REPLACE(p."เริ่มเล่นเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p')::date = DATE '2026-07-12'
