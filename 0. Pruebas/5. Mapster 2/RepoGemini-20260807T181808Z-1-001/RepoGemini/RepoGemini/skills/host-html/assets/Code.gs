/**
 * Backend del web app. Sirve index.html tal cual (HTML estático).
 * Si necesitás interpolar datos del backend o leer query params,
 * pasá al patrón con plantilla (ver references/advanced.md).
 */
function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('__TITLE__')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
