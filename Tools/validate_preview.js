// npm install playwright, then npx playwright install chromium.
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
(async () => {
  const portable = process.env.NOCTURNE_CHROMIUM_MODULE ? require(process.env.NOCTURNE_CHROMIUM_MODULE) : null;
  const browser = await chromium.launch(process.env.NOCTURNE_BROWSER_EXECUTABLE ?
    {headless:true,executablePath:process.env.NOCTURNE_BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-gpu']} :
    portable ? {headless:true,executablePath:await portable.executablePath(),args:portable.args} : {headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:1});
  const root = path.resolve(__dirname,'..');
  const url = pathToFileURL(path.join(root,'Preview/menu-preview.html')).href;
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.goto(url);await page.screenshot({path:path.join(root,'Preview/main-menu.png')});
  await page.getByRole('button',{name:/Cryomancer/}).click();
  if(await page.locator('[data-order="Cryomancer"]').getAttribute('aria-pressed')!=='true')throw Error('Order selection failed');
  await page.getByRole('button',{name:/Grimoire/}).click();await page.getByRole('heading',{name:'IGNIS'}).waitFor();
  await page.getByRole('button',{name:'Return to the menu'}).click();
  await page.getByRole('button',{name:/Settings/}).click();await page.getByLabel('Floating embers').uncheck();
  if(!await page.locator('.stars').isHidden())throw Error('Ember setting failed');
  await page.getByRole('button',{name:'Return to the menu'}).click();
  await page.getByRole('button',{name:/Enter the court/}).click();await page.getByRole('heading',{name:'Your trial awaits'}).waitFor();
  await page.getByRole('button',{name:'Return to the menu'}).click();
  await page.goto(url+'?screen=loading');await page.screenshot({path:path.join(root,'Preview/loading-screen.png')});
  await page.setViewportSize({width:852,height:393});await page.goto(url);await page.screenshot({path:path.join(root,'Preview/menu-landscape.png')});
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  console.log(JSON.stringify({previewErrors:errors,landscapeHorizontalOverflow:overflow,flows:['class selection','grimoire open/close','settings toggle','menu to loading to native-build notice']},null,2));
  if(errors.length||overflow)throw Error('Preview validation failed');
  await browser.close();
})().catch(error=>{console.error(error);process.exit(1)});
