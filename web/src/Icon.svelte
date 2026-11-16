<script>
  let { name, size = 18 } = $props();
  const paths = {
    case: 'M3 7h18v13H3z M8 7V4h8v3 M3 12h18 M10 12v2h4v-2',
    chat: 'M4 4h16v13H9l-5 4z M8 9h8 M8 12h5',
    location: 'M19 10c0 5-7 10-7 10S5 15 5 10a7 7 0 0 1 14 0z M12 8a2 2 0 1 0 0 4 2 2 0 1 0 0-4',
    compass: 'M3 11 21 3 13 21l-2-8z',
    search: 'M16 10a6 6 0 1 1-12 0 6 6 0 1 1 12 0z M14.5 14.5l5 5',
    close: 'M6 6l12 12 M18 6 6 18', back: 'M19 12H5m7-7-7 7 7 7', next: 'M5 12h14m-7-7 7 7-7 7',
    play: 'M9 5v14l11-7z', image: 'M3 4h18v16H3z M3 16l5-5 5 5 3-3 5 5 M16 8h.01',
    up: 'M7 10V21H3V10z M7 20h11l3-8v-2h-7l1-5-2-2-6 7',
    down: 'M7 14V3H3v11z M7 4h11l3 8v2h-7l1 5-2 2-6-7',
    plus: 'M12 5v14M5 12h14', settings: 'M4 6h16 M4 12h16 M4 18h16 M8 3v6 M15 9v6 M10 15v6',
    camera: 'M3 7h4l2-3h6l2 3h4v13H3z M15 13a3 3 0 1 1-6 0 3 3 0 1 1 6 0z',
    beacon: 'M12 3v4m0 10v4M3 12h4m10 0h4 M12 8a4 4 0 1 1 0 8 4 4 0 1 1 0-8z',
  };
</script>
<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d={paths[name] || paths.case}/></svg>
