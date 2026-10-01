# Bildtillgångar

## Markos foto

Webbplatsens enda nuvarande foto är Marko Valtakoskis tillhandahållna bild. Den hämtas direkt från användarens Dropbox-delning och visas som porträtt i hero och Om-avsnittet, inte som ett kundprojekt. Webbplatsen behöver internetanslutning för att hämta bilden.

För att använda en lokal kopia kan du spara originalbilden som `marko-valtakoski.png` här och ersätta Dropbox-adressen i `index.html` på fyra ställen: `og:image`, `twitter:image`, preload-länken och de två `<img>`-elementen (hero och Om). Anpassa även `width` och `height` om bildens originalmått ändras.

## Framtida projekt

Det finns inga verifierade projektbilder i webbplatsen. `index.html` innehåller en dold `<template id="project-card-template">` som kan dupliceras när riktiga projekt har godkänts för publicering. Använd endast bilder från företagets faktiska uppdrag, med tillstånd; beskriv projektets omfattning och plats korrekt. Märk aldrig generiska referensbilder som utfört arbete.

För en snabb och lätt webbplats: komprimera godkända bilder till WebP eller AVIF, ange korrekta pixelmått, använd beskrivande alt-text och lazy-loada bilder som ligger utanför första skärmen.
