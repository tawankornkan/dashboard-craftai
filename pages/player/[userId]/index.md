---
title: Player Detail
hide_header: true
hide_breadcrumbs: true
hide_toc: true
sidebar: never
---

<!--
  Evidence OSS doesn't apply frontmatter (hide_header/hide_toc/sidebar/hide_breadcrumbs)
  on templated [param] pages, so we hide the default chrome manually here.
-->
<div id="player-detail-marker" class="hidden"></div>

<style>
  :global(.antialiased:has(#player-detail-marker) header),
  :global(.antialiased:has(#player-detail-marker) aside) {
    display: none !important;
  }
  :global(.antialiased:has(#player-detail-marker) main) {
    margin: 1.5rem auto 0 !important;
    padding: 0 1.5rem !important;
    max-width: 80rem !important;
    float: none !important;
  }
  :global(.antialiased:has(#player-detail-marker) main > div:has(a[href="/"])) {
    display: none !important;
  }
</style>

[← Back to overview](/)

```sql player_profile
select
    coalesce(u."ชื่อเล่น", '(no name)') as nickname,
    coalesce(nullif(nullif(trim(u."อาชีพ"), ''), '-'), 'Not specified') as occupation,
    coalesce(nullif(nullif(trim(u."สังกัด"), 'null'), '-'), 'Not specified') as affiliation,
    nullif(try_cast(u."อายุ" as integer), 1) as age
from users u
where u.userId = '${params.userId}'
```

<Grid cols=4>
    <BigValue data={player_profile} value=nickname title="Nickname"/>
    <BigValue data={player_profile} value=occupation title="Occupation"/>
    <BigValue data={player_profile} value=affiliation title="Affiliation"/>
    <BigValue data={player_profile} value=age title="Age" fmt=num0/>
</Grid>

```sql sessions
-- Source timestamps are stored in UTC; shift by +7 hours to show Thailand local time
-- (matches the "When People Play" chart on the overview page).
select
    p.activityId,
    p."ชื่อกิจกรรม" as activity_name,
    p."ประเภท" as activity_type,
    try_strptime(replace(p."เริ่มเล่นเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') + interval '7 hours' as started_at,
    try_strptime(replace(p."เล่นจบเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') + interval '7 hours' as finished_at,
    coalesce(
        strftime(try_strptime(replace(p."เล่นจบเมื่อ", chr(8239), ' '), '%b %d, %Y, %-I:%M:%S %p') + interval '7 hours', '%-I:%M:%S %p'),
        'Not finished'
    ) as finished_display
from play_results p
where p.userId = '${params.userId}'
order by started_at
```

```sql kpis
select
    count(*) as total_sessions,
    count(distinct activity_name) as activities_tried,
    count(finished_at) as completed_sessions,
    count(finished_at) * 1.0 / count(*) as completion_rate,
    lpad(floor(avg(epoch(finished_at) - epoch(started_at)) filter (where finished_at is not null) / 60)::bigint::varchar, 2, '0')
        || ':' ||
        lpad((round(avg(epoch(finished_at) - epoch(started_at)) filter (where finished_at is not null))::bigint % 60)::varchar, 2, '0')
        as avg_duration_mmss
from ${sessions}
```

<Grid cols=4>
    <BigValue data={kpis} value=total_sessions title="Total Sessions" fmt=num0/>
    <BigValue data={kpis} value=activities_tried title="Activities Tried" fmt=num0/>
    <BigValue data={kpis} value=completion_rate title="Completion Rate" fmt=pct1/>
    <BigValue data={kpis} value=avg_duration_mmss title="Avg. Activity Duration (mm:ss)" fmt="@"/>
</Grid>

## Activity History

```sql activity_breakdown
select
    activity_name,
    activity_type,
    count(*) as sessions
from ${sessions}
group by 1, 2
order by sessions desc
```

<BarChart
    data={activity_breakdown}
    x=activity_name
    y=sessions
    title="Sessions by Activity"
    swapXY=true
    sort=true
/>

## Session Log

<DataTable data={sessions} search=true>
    <Column id=activity_name title="Activity"/>
    <Column id=activity_type title="Type"/>
    <Column id=started_at title="Started" fmt=hms/>
    <Column id=finished_display title="Finished"/>
</DataTable>
