---
title: Kapibarian Demo @CraftAI - Player Insights
hide_header: true
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

```sql occupation_groups
select distinct
    case
        when occupation is null then 'ไม่ระบุ'
        when occupation in ('นักเรียน', 'ครู', 'ผู้บริหารการศึกษา', 'ผู้ปกครอง', 'นักวิจัย', 'นักการศึกษา') then occupation
        else 'อื่น ๆ'
    end as occupation_group
from ${base}
order by occupation_group
```

<Dropdown
    name=occupation_filter
    data={occupation_groups}
    value=occupation_group
    title="Filter by Occupation"
>
    <DropdownOption value="%" valueLabel="All Occupations"/>
</Dropdown>

```sql filtered
select *
from (
    select
        *,
        case
            when occupation is null then 'ไม่ระบุ'
            when occupation in ('นักเรียน', 'ครู', 'ผู้บริหารการศึกษา', 'ผู้ปกครอง', 'นักวิจัย', 'นักการศึกษา') then occupation
            else 'อื่น ๆ'
        end as occupation_group
    from ${base}
)
where occupation_group like '${inputs.occupation_filter.value}'
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
from ${filtered}
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
from ${filtered}
group by 1, 2
order by sessions desc
```

```sql activity_type_breakdown
select
    activity_type,
    count(*) as sessions
from ${filtered}
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
from ${filtered}
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
    occupation_group,
    count(distinct userId) as players
from ${filtered}
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
from ${filtered}
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
from ${filtered}
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
