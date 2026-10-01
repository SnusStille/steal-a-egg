# MV Riv & Bygg — webbplats

Fristående, responsiv webbplats byggd med HTML, CSS och JavaScript. Den använder inga externa paket, externa typsnitt eller tredjepartsskript.

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

Den färdiga statiska webbplatsen hamnar i `dist/`. Ingen officiell domän har angetts, därför finns ingen påhittad canonical-adress. När rätt domän är känd kan sitemap och robots-fil skapas samtidigt:

```bash
SITE_URL=https://foretagets-riktiga-domän.se npm run build
```

I PowerShell:

```powershell
$env:SITE_URL = "https://foretagets-riktiga-domän.se"
npm run build
```

Sitemap-generatorn kan även köras fristående: `node scripts/generate-sitemap.mjs https://foretagets-riktiga-domän.se`.

## Företagsuppgifter och innehåll

- MV Riv & Bygg drivs av Marko Valtakoski och har sin bas i Skene.
- Telefonnumret `070 281 10 03` länkas som ett klickbart `tel:`-nummer.
- Registreringsår `2007` är inte omskrivet till ett påstående om antal års erfarenhet.
- Tjänsteöversikten beskriver rivning, bygg och entreprenad enligt användarens bekräftelse samt registrerade verksamhetsområden. Sanering, håltagning, bilning, totalentreprenad och andra ej bekräftade specialiteter marknadsförs inte.
- Ingen verifierad e-postadress, gatuadress, organisationsnummer, certifiering, försäkring, garanti, kundrecension eller dokumenterad projektprestation har lagts till.
- Inga påhittade kundcase eller projektbilder används. Den tidigare tomma projektpanelen är ersatt med en praktisk checklista inför första kontakten.

Källor för offentligt listade företagsuppgifter:

- [Allabolag — MV Riv & Bygg](https://www.allabolag.se/foretag/mv-riv-bygg/skene/byggm%C3%A4stare/7VJQ7AOX4I5YDDT)
- [Allabolag — Marko Valtakoski](https://www.allabolag.se/foretag/marko-valtakoski/skene/byggm%C3%A4stare/O4X30ZI8MI5YDDT)

## Bilder

Bilderna från Unsplash och Pexels är lokala WebP-referenser, märkta så att de inte misstas för MV Riv & Byggs arbeten. Markos porträtt i hero och Om-avsnittet hämtas från den Dropbox-länk som användaren delade; det är den enda externa bildresursen. För att webbplatsen ska visa Markos foto krävs internetanslutning. Källor och bildinstruktioner finns i [`assets/README.md`](assets/README.md).

Vill du göra projektet helt fristående/offline: ladda ned det delade fotot till `assets/marko-valtakoski.png` och byt Dropbox-adressen i `index.html` (hero, Om, preload och sociala delningsbilder) mot den lokala sökvägen. Projektbilder ska bara läggas till när de visar verkliga uppdrag som får publiceras. När rätt webbdomän är känd kan canonical och sitemap byggas med den domänen.

## Offertformulär — viktigt

Det här är en statisk webbplats och inget formulär skickas till en server. När besökaren fyller i formuläret skapas ett SMS-utkast till `070 281 10 03`; besökaren granskar och skickar det själv. Det finns även en kopiera-knapp för enheter där SMS-länk inte kan öppnas. Valda bilder/filer bifogas inte automatiskt utan behöver läggas till i meddelandeappen.

Om formuläret senare ska skicka e-post eller lagra förfrågningar måste det kopplas till en verifierad e-postadress eller en säker formulärtjänst. Lägg då till tydlig integritetsinformation innan uppgifter samlas in.
