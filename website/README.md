# MV Riv & Bygg — webbplats

En fristående, responsiv webbplats med statiska HTML-, CSS- och JavaScript-filer. Roblox-projektets befintliga struktur och källkod är orörda. Inga paket behöver installeras.

## Testa i VS Code

1. Packa upp `MV-Riv-Bygg-Webbplats.zip`.
2. Öppna den uppackade mappen **MV-Riv-Bygg-Webbplats** i VS Code.
3. Öppna terminalen i mappen och kör:

   ```bash
   npm run dev
   ```

4. Öppna adressen som visas — normalt `http://localhost:5173`.

Alternativt: öppna **Terminal → Run Task… → MV Riv & Bygg: start dev server**. Ändringar visas när du sparar och laddar om webbläsaren. Kräver Node.js 18 eller senare; inga `npm install` behövs.

## Bygg för publicering

```bash
npm run build
npm run preview
```

Den färdiga statiska webbplatsen hamnar i `dist/`. Ingen officiell webbdomän var angiven eller kunde verifieras, så ingen påhittad canonical-adress används. När rätt domän är känd kan sitemap och Sitemap-raden i `robots.txt` byggas samtidigt:

```bash
SITE_URL=https://din-riktiga-domän.se npm run build
```

I PowerShell:

```powershell
$env:SITE_URL = "https://din-riktiga-domän.se"
npm run build
```

Sitemap-generatorn går även att köra fristående: `node scripts/generate-sitemap.mjs https://din-riktiga-domän.se`.

## Faktagrund och kontakt

- MV Riv & Bygg, Skene, drivs av Marko Valtakoski.
- Telefonnumret `070 281 10 03` är offentligt listat och länkat som `tel:`. Ingen verifierad e-postadress hittades, därför visas ingen.
- Verksamhetsområdena följer registrerad företagsinformation: bygg och renovering, byggnadssnickeri, golv- och väggbeläggning, måleriarbeten samt skötsel av grönytor.
- `2007` anges som registreringsår — inte som ett påstående om ett visst antal års erfarenhet.
- Ingen gatuadress, kund, recension, certifiering, garanti eller projektprestation har lagts till. Rivning har inte lyfts fram som en separat tjänst eftersom det inte kunde verifieras i verksamhetsuppgifterna.

Källor:

- [Allabolag — MV Riv & Bygg](https://www.allabolag.se/foretag/mv-riv-bygg/skene/byggm%C3%A4stare/7VJQ7AOX4I5YDDT)
- [Allabolag — Marko Valtakoski, kontaktuppgifter](https://www.allabolag.se/foretag/marko-valtakoski/skene/byggm%C3%A4stare/O4X30ZI8MI5YDDT)

## Egna projektbilder

Bildplatserna under **Arbeten** är avsiktligt inte fyllda med lånade projektbilder. Ersätt varje `.project-art`-yta i `index.html` med ett optimerat, godkänt foto från ett faktiskt MV Riv & Bygg-arbete och skriv en kort, saklig alt-text. Spara bilderna i `assets/projects/`. De redaktionella referensbilder som används i hero/tjänster är tydligt märkta och källorna finns i [`assets/README.md`](assets/README.md).
