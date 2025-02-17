let fs = require( "fs" );
let path = require( "path" );
let os = require( "os" );
//const util = require('util');
const { execFile } = require('child_process');

function expandTilde(filePath) {
  //console.log( "expandTilde", filePath )
  if (filePath.startsWith('~')) {
    //console.log( "tilde!", os.homedir(), filePath.slice(1), path.join(os.homedir(), filePath.slice(1)) )
    return path.join(os.homedir(), filePath.slice(1));
  }
  return filePath;
}
module.exports.expandTilde = expandTilde


function getAbsolutePath(filePath) {
  // If the path is already absolute, return it as is
  if (path.isAbsolute(filePath)) {
    return filePath;
  }

  // Otherwise, resolve it to an absolute path
  return path.resolve(filePath);
}
module.exports.getAbsolutePath = getAbsolutePath

function exec( cmd, args ) {
  let child = execFile(cmd, args, (error, stdout, stderr) => {
    if (error) {
      console.error(`[${cmd}] error: ${error}`);
      return;
    }

    console.log(`[${cmd}] stdout: ${stdout}`);
    console.error(`[${cmd}] stderr: ${stderr}`);
  });
  return child;
}
module.exports.exec = exec

async function timeout( n ) {
  return new Promise( (rs, rj) => setTimeout( () => rs(), n ) );
}
module.exports.timeout = timeout

function getShareUrl(docId) {
  return `https://drive.google.com/file/d/${docId}/view?usp=sharing`
}
module.exports.getShareUrl = getShareUrl

function getExportUrl(type, docId, format) {
  const baseUrls = {
    document: `https://docs.google.com/document/d/${docId}/export?format=${ (format=="office"||format=="doc")?"docx":format }`,
    presentation: `https://docs.google.com/presentation/d/${docId}/export/${ (format=="office"||format=="doc")?"pptx":format }`,
    spreadsheets: `https://docs.google.com/spreadsheets/d/${docId}/export?format=${ (format=="office"||format=="doc")?"xlsx":format }`,
    file: `https://drive.google.com/uc?export=download&id=${docId}`,
  };
  if (baseUrls[type] == undefined) {
    console.log( "undefined", type, docId, format )
    console.log( "baseUrls", baseUrls )
  }
  return baseUrls[type] || null;
}
module.exports.getExportUrl = getExportUrl

function getID( driveShareURL ) {
  return driveShareURL.replace( /^.+\/d\/([^/]+).*$/, "$1" )
}
module.exports.getID = getID

function getType( driveShareURL ) {
  return driveShareURL.replace( /^.+\/([^/]+)\/d\/.*$/, "$1" )
}
module.exports.getType = getType

// get a list of files from a directory, using matching patterns
function readdirRecursiveSync(f, options = { whitelist: ['.*\.gdoc$', '.*\.gslides$', '.*\.gsheet$'], blacklist: [] } ) {
  if (!fs.statSync( f ).isDirectory()) {
    let wl = options.whitelist.length === 0 || options.whitelist.filter( r => f.match( new RegExp( r ) ) ).length !== 0;
    let bl = options.blacklist.length > 0 && options.blacklist.filter( r => f.match( new RegExp( r ) ) ).length !== 0;
    if (wl && !bl)
      return [f]
    else
      return []
  } else {
    let files = fs.readdirSync( f );
    let results = [];
    for (let file of files) {
      let r = readdirRecursiveSync(path.join( f, file), options);
      results = results.concat( r );
    }
    return results;
  }
}
module.exports.readdirRecursiveSync = readdirRecursiveSync

function gdriveFileToExportURL( f, format ) {
  // look at the file extension in ~/Google Docs/*.*
  let type = f.match( /gdoc$/ ) ? "document" : f.match( /gslides$/ ) ? "presentation" : f.match( /gsheet$/ ) ? "spreadsheets" : undefined
  if (type == undefined) {
    console.log( `unknown type: ${f}` )
    return undefined
  }
  let obj = JSON.parse(fs.readFileSync(f, 'utf8'));
  return getExportUrl( type, obj.doc_id, format );
}
module.exports.gdriveFileToExportURL = gdriveFileToExportURL

function gdriveExportUrlChangeFormat( driveShareURL, format ) {
  let id = getID( driveShareURL )
  let type = getType( driveShareURL )
  let new_url = getExportUrl( type, id, format );
  return new_url;
}
module.exports.gdriveExportUrlChangeFormat = gdriveExportUrlChangeFormat

function mkpath(dirPath) {
  const absolutePath = path.resolve(dirPath);
  if (!fs.existsSync(absolutePath)) {
    console.log(`mkpath: ${absolutePath}`);
    fs.mkdirSync(absolutePath, { recursive: true });
  }
}
module.exports.mkpath = mkpath

// function isSharingURL( url ) {
//   return url.match( /^https:\/\/drive\.google\.com\/file\/d\/.*edit\?usp=sharing$/ ) != undefined
// }
// module.exports.isSharingURL = isSharingURL

function isExportDocsURL( url ) {
  return url.match( /^https:\/\/docs\.google\.com\/document\/d\/[^/]+\/export.*$/ ) != undefined
}

function isExportSlidesURL( url ) {
  return url.match( /^https:\/\/docs\.google\.com\/presentation\/d\/[^/]+\/export.*$/ ) != undefined
}

function isExportSheetsURL( url ) {
  return url.match( /^https:\/\/docs\.google\.com\/spreadsheets\/d\/[^/]+\/export.*$/ ) != undefined
}

function isExportFileURL( url ) {
  return url.match( /^https:\/\/drive\.google\.com\/uc\?export.*$/ ) != undefined
}

function isExportURL( url ) {
  return  isExportDocsURL( url ) ||
          isExportSlidesURL( url ) ||
          isExportSheetsURL( url ) ||
          isExportFileURL( url )
}
module.exports.isExportURL = isExportURL

function replacePathPrefix(filePath, oldPrefix, newPrefix) {
  const regex = new RegExp(`^${oldPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`);
  return filePath.replace(regex, newPrefix);
}
module.exports.replacePathPrefix = replacePathPrefix

function extractFilename_FromContentDisposition(contentDisposition) {
  const match = contentDisposition.match(/filename="([^"]+)"/);
  if (match) {
      return matches[1];
  }
  return undefined;
}
module.exports.extractFilename_FromContentDisposition = extractFilename_FromContentDisposition

function extractFilenameStar_FromContentDisposition(contentDisposition) {
  const match = contentDisposition.match(/filename\*=(?:UTF-8''|)(["']?)(.*?)\1(?:;|$)/i);
  if (match) {
      return decodeURIComponent(match[2]); // Decode URL encoding if present
  }
  return undefined;
}
module.exports.extractFilenameStar_FromContentDisposition = extractFilenameStar_FromContentDisposition
