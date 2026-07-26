<script>
	import '@evidence-dev/tailwind/fonts.css';
	import '../app.css';
	import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
	import { navigating } from '$app/stores';
	export let data;
</script>

<!--
  Header/sidebar visibility is driven by each page's frontmatter, but that only
  gets recomputed after the destination route's data has loaded. During that gap,
  a client-side navigation (e.g. clicking browser back from the player detail page)
  briefly shows the header/sidebar before they disappear again. Hiding them for the
  duration of `$navigating` closes that gap.
-->
<div class:navigating={!!$navigating}>
	<EvidenceDefaultLayout {data}>
		<slot slot="content" />
	</EvidenceDefaultLayout>
</div>

<style>
	:global(.navigating header),
	:global(.navigating aside) {
		display: none !important;
	}
</style>
