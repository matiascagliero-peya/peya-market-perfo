/**
 * =========================================================================================
 * ARCHIVO DE CONFIGURACIÓN COMPARTIDA
 * =========================================================================================
 * Este archivo contiene las únicas variables que son 100% compartidas por todas las tareas.
 * Al declararlas una sola vez aquí, evitamos errores.
 * =========================================================================================
 */

// ID del archivo "maestro" de LATAM, de donde se copia todo.
const SOURCE_SPREADSHEET_ID = "1H_gDXL9IQ9HCHSAzzDT8oGBNwPIw4rHmbjtqcqKJikc";

// Lista de todos los archivos de destino. Es la misma para todas las tareas.
const PAISES_DE_DESTINO = [
  { id: "1rB6CkpTrzmnMGXSMUci2SPIoNBgUaIZQZxr3bEYaTzg", country: "Argentina" },
  { id: "14cLnA8d09zaoA-Num-yXhmCWqq_TSkx_WbR1DhN6fy8", country: "Uruguay" },
  { id: "1ftJjSq6fPBH29hir7jb746eF13rQRb3-DDkwEhlSv9U", country: "Bolivia" },
  { id: "1dtGRrz4sZUZOzksMQV8yGfZgWbH8n1J7clMeogV_GoY", country: "Chile" },
  { id: "1a4gUgeQr5izwQmUTIT8lpyunO_TWWDGLhtlSYinqyWo", country: "Republica Dominicana" },
  { id: "1NnLsttldtLmbFfLlUcc1-g-n4Un7pQDWu8MoiLPn3To", country: "Ecuador" },
  { id: "11M9TRrrW3qyeVT5Tt4JV4t4PC9AwVNWcLYbFsJq2VCk", country: "El Salvador" },
  { id: "1KYSngPncZVACz6kbLRojUWbBU-XYXebYyJ8ZMM0V5_0", country: "Guatemala" },
  { id: "1N-wNtDJNFsqMeDoOsXMUxK-Q9tVv7lWhS9XKnbIV44U", country: "Honduras" },
  { id: "10Z34v86M_79cifmTTfvQVJ-x7pkbAq9y9I1GyyC9daE", country: "Nicaragua" },
  { id: "1E7GCIwkyrD2Ple1SALlIeusdY0wuLprJHkLzII6vtvc", country: "Panama" },
  { id: "1CtwrSQfaR5fp-LI360SUQUmdRz_3ghWMdRFz8gWXhzA", country: "Paraguay" },
  { id: "16qF6BsorD-kcHg6p4Acy7a3VdgRRCotjwwH5t8vj9ok", country: "Peru" },
  { id: "1dGAwLGz9cRuKmxPylgcPcGDINf2uNFOGMIOcVIuhs3g", country: "Pruebas LATAM" }
];

const ID_PPT_TEMPLATE = "1gOxyBphLUm5k5az_azDd-OKWEa-ypI1YlkRNGcETV5A";

const PPTs_PAISES_DE_DESTINO = [
  { id: "1OFkJy181Og0AdYvqBvKSMM63e8UIacNuDMN9KEPK9ck", country: "Argentina" },
  { id: "17o2QpmoNvFM_6QPS3COlkzW3_344TyPTHh3X28Z4PaY", country: "Bolivia" },
  { id: "18RZHbuiQ9nQOyYvq-vKtASbbOfUP74PEtOUTtXEJFh0", country: "Chile" },
  { id: "1NYyZLn04nG9HQdGHUfrNeijd9Df5SEYqP9su23GfHuo", country: "Republica Dominicana" },
  { id: "1MbDyWhcG0-DkbxEVqw2SfUMuWOdvXKC_3Au0dijMQR4", country: "Ecuador" },
  { id: "1d5YCtYxuIiIYyBHduahQzZ5mSxersIVBkmvTEbD1zM4", country: "El Salvador" },
  { id: "1jceC-QneCcI_z83MSODZkwREmH4xfWx_q54A9vWomOk", country: "Guatemala" },
  { id: "1lBX4DK9elbzBepfspcly1T1uPhTVbUUbJ6me1q8b9zU", country: "Honduras" },
  { id: "1EWBMUh0spjcKnEWpxrEO-HMSdlyrm6uOFGdsXf8RXS8", country: "Nicaragua" },
  { id: "1q5nzmkG6p-i52E57WnArNrb3X-n079o0ZhGOuoIUYGY", country: "Panama" },
  { id: "1kZaeeHEizDEZ_7XqUVS4hs0yWV1V8Op4ljRlgwsilxo", country: "Paraguay" },
  { id: "1t5joU83Menrw5cbIwQY9sG28NUg5OchWYQeabSMjSL4", country: "Peru" },
  { id: "1vyuTNzgQYWaSMwipWuv02tDUM4-DT-87vs8bp7T4028", country: "Uruguay" }
];

// Solo para el A. TI - Actuals OKRs
const DESTINOS_ADICIONALES = [
  { id: "1jn3O8Fkh1AIOeFJaX-2SXPt43FkC0cv6VR3BlkpbNLI", alias: "MPC S Team" },
  { id: "1cy2rAvbx2Wbnrgn_ArHmzSxhwlAxWBxCbdvAWogg-Bo", alias: "Dmarts Perfomance Commercial" },

];