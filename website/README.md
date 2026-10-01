# MV Riv & Bygg — webbplats

En responsiv, fristående webbplats byggd med HTML, CSS och vanlig JavaScript. Inga paket, externa typsnitt eller tredjepartsskript behövs. Webbplatsen använder Markos tillhandahållna foto via Dropbox; just den bilden kräver internetanslutning.

## Testa i VS Code

1. Packa upp `MV-Riv-Bygg-Webbplats.zip`.
2. Öppna mappen **MV-Riv-Bygg-Webbplats** i VS Code.
3. Öppna terminalen i projektmappen och kör:

   ```bash
   npm run dev
   ```

4. Öppna adressen som visas — normalt `http://localhost:5173`.

Det går också att välja **Terminal → Run Task… → MV Riv & Bygg: start dev server**. Kräver Node.js 18 eller senare; `npm install` behövs inte.

## Bygg för publicering

```bash
npm run build
npm run preview
```

Den färdiga statiska webbplatsen hamnar i `dist/`. Ingen officiell domän har angetts, så projektet hittar inte på en canonical-adress eller sitemap. När den riktiga domänen är känd kan sitemap och robots-fil skapas samtidigt:

```bash
SITE_URL=https://foretagets-riktiga-domän.se npm run build
```

I PowerShell:

```powershell
$env:SITE_URL = "https://foretagets-riktiga-domän.se"
npm run build
```

Sitemap-generatorn kan även köras fristående: `node scripts/generate-sitemap.mjs https://foretagets-riktiga-domän.se`.

## Innehåll och företagsuppgifter

- Företaget drivs av Marko Valtakoski, med bas i Skene, Marks kommun, Västra Götaland.
- Telefonnumret `070 281 10 03` är klickbart på hela sidan.
- Registreringsåret 2007 anges inte som ett påstående om antal års erfarenhet.
- Tjänsteöversikten beskriver rivning, bygg och entreprenad samt registrerade verksamhetsområden: renovering, byggnadssnickeri, golv- och väggarbeten, måleri och skötsel av grönytor.
- Inga verifierade kundprojekt visas. En dold `<template>` i `index.html` är en enkel startpunkt för framtida, godkända projektkort. Lägg bara in riktiga uppdrag med tillstånd och beskriv dem korrekt.
- Ingen obekräftad e-postadress, organisationsuppgift, certifiering, försäkring, garanti, kundrecension eller projektprestation har lagts till. Inte heller marknadsförs obekräftade specialiteter som sanering, asbest, håltagning, bilning eller totalentreprenad.

Källor för offentligt listade företagsuppgifter:

- [Allabolag — MV Riv & Bygg](https://www.allabolag.se/foretag/mv-riv-bygg/skene/byggm%C3%A4stare/7VJQ7AOX4I5YDDT)
- [Allabolag — Marko Valtakoski](https://www.allabolag.se/foretag/marko-valtakoski/skene/byggm%C3%A4stare/O4X30ZI8MI5YDDT)

## Foto och projektbilder

Markos riktiga foto kommer från Dropbox-bilden som användaren delade. Det används som porträtt i hero och Om-avsnittet, aldrig som kundprojekt. Dropbox är den enda externa bildresursen. Foto, delningsmetadata och preload pekar på samma bildadress. Se [`assets/README.md`](assets/README.md) om du vill göra bilden lokal eller lägga till riktiga projekt senare.

Inga generiska stockbilder visas eller märks som företagets utförda arbeten. Projektkortsmallen ligger inuti ett `<template>`-element och visas inte förrän den fylls med verifierat material.

## Offertformulär — viktigt

Webbplatsen är statisk och formuläret skickar inte uppgifter till en server. Det kontrollerar fälten lokalt och skapar ett SMS-utkast till `070 281 10 03`; besökaren granskar och skickar själv. Det finns en kopiera-knapp om meddelandeappen inte öppnas. Eventuella valda bilder/filer bifogas inte automatiskt — de behöver läggas till i SMS-appen. Formuläret begränsar bilagor till högst fyra bild- eller PDF-filer på 10 MB per fil.

Om formuläret i framtiden ska skicka e-post eller spara förfrågningar behöver det kopplas till en verifierad mottagare eller en säker formulärtjänst. Lägg då till tydlig integritetsinformation innan uppgifter samlas in.

## Tillgänglighet och prestanda

- Responsiv layout med mobilnavigation, tydliga fokusmarkeringar och stora tryckytor.
- Semantiska sektioner, hoppa-till-innehåll-länk, etiketter på formulärfält och FAQ byggd med inbyggda `details`/`summary`.
- Rörelse respekterar `prefers-reduced-motion`; innehåll är tillgängligt även utan JavaScript.
- Systemtypsnitt, inline-ikoner och inga JavaScript-/CSS-bibliotek.
