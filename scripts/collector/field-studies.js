(function () {
  let state = parseInt(tokenHash.slice(2, 10), 16) ^ Number(tokenId);
  function next() {
    state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
    return (state >>> 0) / 4294967296;
  }
  const palettes = [
    ["#101820", "#f4efe5", "#e4572e", "#76b5b2"],
    ["#162521", "#f1e9da", "#d7b377", "#87a878"],
    ["#22223b", "#f2e9e4", "#c9ada7", "#9a8c98"]
  ];
  const colors = palettes[Math.floor(next() * palettes.length)];
  let svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 840" role="img" aria-label="Stream Field Studies">';
  svg += '<rect width="720" height="840" fill="' + colors[0] + '"/>';
  for (let y = 0; y < 6; y++) {
    for (let x = 0; x < 6; x++) {
      const cx = 90 + x * 108, cy = 94 + y * 108;
      const radius = 18 + Math.floor(next() * 29);
      const color = colors[1 + Math.floor(next() * 3)];
      const rotation = Math.floor(next() * 4) * 90;
      if (next() < 0.5) {
        svg += '<circle cx="' + cx + '" cy="' + cy + '" r="' + radius + '" fill="none" stroke="' + color + '" stroke-width="7"/>';
        svg += '<path d="M' + (cx - radius) + ' ' + cy + 'h' + radius * 2 + '" stroke="' + color + '" stroke-width="2" transform="rotate(' + rotation + ' ' + cx + ' ' + cy + ')"/>';
      } else {
        svg += '<rect x="' + (cx - radius) + '" y="' + (cy - radius) + '" width="' + radius * 2 + '" height="' + radius * 2 + '" rx="' + Math.floor(next() * radius) + '" fill="' + color + '" transform="rotate(' + rotation + ' ' + cx + ' ' + cy + ')"/>';
      }
    }
  }
  svg += '<path d="M42 726h636" stroke="' + colors[1] + '"/>';
  svg += '<text x="42" y="767" fill="' + colors[1] + '" font-family="monospace" font-size="17">STREAM / FIELD STUDIES / ' + tokenId + '</text>';
  svg += '<text x="42" y="796" fill="' + colors[2] + '" font-family="monospace" font-size="12">' + tokenHash.slice(2, 50) + '</text></svg>';
  document.body.style.margin = "0";
  document.body.style.background = colors[0];
  document.body.innerHTML = svg;
})();
