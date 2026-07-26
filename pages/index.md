---
title: Kapibarian Demo @CraftAI - Player Insights
hide_header: false
hide_breadcrumbs: true
hide_toc: true
sidebar: never
---

On July 12, 2026, who's playing the [Kapibarian Demo](https://craft-ai.demo.kapibarian.com/), and how are they engaging with it?

```sql base
select
    p.userId,
    p.activityId,
    p."ชื่อกิจกรรม" as activity_name,
    p."ประเภท" as activity_type,
    try_strptime(replace(p."เริ่มเล่นเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') as started_at,
    try_strptime(replace(p."เล่นจบเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') as finished_at,
    nullif(try_cast(u."อายุ" as integer), 1) as age,
    nullif(nullif(trim(u."อาชีพ"), ''), '-') as occupation,
    nullif(nullif(trim(u."สังกัด"), 'null'), '-') as affiliation,
    u."ชื่อเล่น" as nickname
from play_results p
left join users u
    on p.userId = u.userId
where try_strptime(replace(p."เริ่มเล่นเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p')::date = date '2026-07-12'
```

```sql kpis
select
    count(*) as total_sessions,
    count(distinct userId) as unique_players,
    count(finished_at) as completed_sessions,
    count(finished_at) * 1.0 / count(*) as completion_rate,
    avg(epoch(finished_at) - epoch(started_at)) filter (where finished_at is not null) as avg_duration_sec,
    lpad(floor(avg(epoch(finished_at) - epoch(started_at)) filter (where finished_at is not null) / 60)::bigint::varchar, 2, '0')
        || ':' ||
        lpad((round(avg(epoch(finished_at) - epoch(started_at)) filter (where finished_at is not null))::bigint % 60)::varchar, 2, '0')
        as avg_duration_mmss
from ${base}
```

<Grid cols=4>
    <BigValue data={kpis} value=total_sessions title="Total Play Sessions" fmt=num0/>
    <BigValue data={kpis} value=unique_players title="Unique Players" fmt=num0/>
    <BigValue data={kpis} value=completion_rate title="Completion Rate" fmt=pct0/>
    <BigValue data={kpis} value=avg_duration_mmss title="Avg. Activity Duration (mm:ss)" fmt="@"/>
</Grid>

## Activity Engagement

```sql activity_popularity
select
    activity_name,
    activity_type,
    count(*) as sessions,
    count(distinct userId) as players
from ${base}
group by 1, 2
order by sessions desc
```

```sql activity_type_breakdown
select
    activity_type,
    count(*) as sessions
from ${base}
group by 1
```

<Grid cols=2>
    <BarChart
        data={activity_popularity}
        x=activity_name
        y=sessions
        title="Sessions by Activity"
        swapXY=true
        sort=true
    />
    <BarChart
        data={activity_type_breakdown}
        x=activity_type
        y=sessions
        title="In-class vs Out-class Sessions"
    />
</Grid>

## When People Play

```sql hourly_trend
select
    date_trunc('hour', started_at) as hour,
    count(*) as sessions
from ${base}
where started_at is not null
group by 1
order by 1
```

<LineChart
    data={hourly_trend}
    x=hour
    y=sessions
    title="Play Sessions by Hour"
    echartsOptions={{tooltip: {formatter: (params) => `Sessions: ${params[0].value[1]}`}}}
/>

## Who's Playing

```sql occupation_breakdown
select
    case
        when occupation is null then 'ไม่ระบุ'
        when occupation in ('นักเรียน', 'ครู', 'ผู้บริหารการศึกษา', 'ผู้ปกครอง', 'นักวิจัย', 'นักการศึกษา') then occupation
        else 'อื่น ๆ'
    end as occupation_group,
    count(distinct userId) as players
from ${base}
group by 1
order by occupation_group = 'อื่น ๆ', players desc
```

```sql age_breakdown
select
    case
        when age is null then 'Not specified'
        when age < 13 then '<13'
        when age between 13 and 17 then '13-17'
        when age between 18 and 24 then '18-24'
        when age between 25 and 34 then '25-34'
        when age between 35 and 44 then '35-44'
        when age between 45 and 59 then '45-59'
        else '60+'
    end as age_group,
    count(distinct userId) as players
from ${base}
group by 1
order by
    case age_group
        when 'Not specified' then 8
        when '<13' then 1
        when '13-17' then 2
        when '18-24' then 3
        when '25-34' then 4
        when '35-44' then 5
        when '45-59' then 6
        else 7
    end
```

<Grid cols=2>
    <BarChart
        data={occupation_breakdown}
        x=occupation_group
        y=players
        title="Players by Occupation"
        swapXY=true
        sort=false
    />
    <BarChart
        data={age_breakdown}
        x=age_group
        y=players
        title="Players by Age Group"
        sort=false
    />
</Grid>

## Player Detail

```sql player_detail
select
    userId,
    coalesce(nickname, '(no name)') as nickname,
    coalesce(occupation, 'Not specified') as occupation,
    coalesce(affiliation, 'Not specified') as affiliation,
    age,
    count(*) as sessions,
    count(distinct activity_name) as activities_tried,
    '/player/' || userId as link
from ${base}
group by 1, 2, 3, 4, 5
order by sessions desc
```

<DataTable data={player_detail} search=true link=link>
    <Column id=nickname title="Nickname"/>
    <Column id=occupation title="Occupation"/>
    <Column id=affiliation title="Affiliation"/>
    <Column id=age title="Age"/>
    <Column id=sessions title="Sessions"/>
    <Column id=activities_tried title="Activities Tried"/>
</DataTable>

## Insight

```sql occupation_edu
select
    sum(case when occ_group = 'Student' then 1 else 0 end) as student_players,
    sum(case when occ_group = 'Teacher / Education staff' then 1 else 0 end) as teacher_players,
    sum(case when occ_group in ('Student', 'Teacher / Education staff') then 1 else 0 end) * 1.0 / count(*) as edu_share
from (
    select distinct
        userId,
        case
            when occupation is null then 'Not specified'
            when occupation ilike '%ครู%' or occupation ilike '%ศึกษานิเทศก์%' or occupation ilike '%ผู้บริหารการศึกษา%' then 'Teacher / Education staff'
            when occupation ilike '%นักเรียน%' or occupation ilike '%นักศึกษา%' then 'Student'
            when occupation ilike '%นักวิจัย%' or occupation ilike '%research%' then 'Researcher'
            when occupation ilike '%ผู้ปกครอง%' then 'Parent'
            when occupation ilike '%software%' or occupation ilike '%วิศวกร%' or occupation ilike '%โปรแกรมเมอร์%' then 'Tech / Engineering'
            when occupation ilike '%พนัก%' or occupation ilike '%รับจ้าง%' or occupation ilike '%ธุรกิจ%' then 'Employee / Business'
            else 'Other'
        end as occ_group
    from ${base}
)
```

```sql age_top
select age_group, players, players * 1.0 / (select count(distinct userId) from ${base}) as share
from (
    select
        case
            when age is null then 'Not specified'
            when age < 13 then '<13'
            when age between 13 and 17 then '13-17'
            when age between 18 and 24 then '18-24'
            when age between 25 and 34 then '25-34'
            when age between 35 and 44 then '35-44'
            when age between 45 and 59 then '45-59'
            else '60+'
        end as age_group,
        count(distinct userId) as players
    from ${base}
    group by 1
)
order by players desc
limit 1
```

```sql depth
with per_user as (
    select userId, count(distinct activity_name) as activities_tried
    from ${base}
    group by 1
)
select
    sum(case when activities_tried = 1 then 1 else 0 end) as single_activity_players,
    sum(case when activities_tried = 1 then 1 else 0 end) * 1.0 / count(*) as single_activity_share,
    sum(case when activities_tried >= 2 then 1 else 0 end) as multi_activity_players,
    sum(case when activities_tried >= 2 then 1 else 0 end) * 1.0 / count(*) as multi_activity_share,
    max(activities_tried) as max_activities
from per_user
```

กลุ่มอาชีพที่มาเล่นเยอะที่สุดคือนักเรียน/นักศึกษา (<Value data={occupation_edu} column=student_players fmt=num0/> คน) รองลงมาคือครูและบุคลากรทางการศึกษา (<Value data={occupation_edu} column=teacher_players fmt=num0/> คน) รวมกันคิดเป็น <Value data={occupation_edu} column=edu_share fmt=pct0/> ของผู้เล่นทั้งหมด ส่วนช่วงอายุที่มาเล่นเยอะที่สุดคือ <Value data={age_top} column=age_group/> ปี

ผู้เล่น <Value data={depth} column=single_activity_share fmt=pct0/> (<Value data={depth} column=single_activity_players fmt=num0/> คน) ลองแค่กิจกรรมเดียวแล้วออกจากบูธไป ในขณะที่อีก <Value data={depth} column=multi_activity_share fmt=pct0/> (<Value data={depth} column=multi_activity_players fmt=num0/> คน) เล่นต่อเนื่องตั้งแต่ 2 กิจกรรมขึ้นไป โดยผู้เล่นที่เล่นเยอะที่สุดลองไปถึง <Value data={depth} column=max_activities fmt=num0/> กิจกรรมในวันเดียว
