#!/usr/bin/env node
let fs = require( "fs" );
let path = require( "path" );
let os = require( "os" );
const util = require('util');
const CDP = require('chrome-remote-interface');
const { spawnSync } = require('child_process');
const lib = require( "./functions" );

// this script's dir (and location of the other tools)
let scriptpath=__filename  // full path to script
let scriptname=__filename.replace( /^.*\//, "" )  // name of script w/out path
let scriptdir=__dirname    // the dir of the script
let cwd=process.cwd()

// options:
let args = [];
let outdir = "./out"
let scandir = "~/Google Drive"
let use_scan = false;
let format = "pdf"
let VERBOSE=false;
let LIST_ONLY=false;

/////////////////////////////////////
// scan command line args:
function usage()
{
  console.log( `${scriptname} - pull exported pdf/docx/pptx files from google drive (remote connect to your chrome browser for cookies/sessiondata)` );
  console.log( `Usage:
   ${scriptname} --help        (this help)
   ${scriptname} --verbose     (output verbose information)
   ${scriptname} --list        (output list of URLS and exit)
   ${scriptname} --scan        (scan the google drive dir recursively for document URLs + paths, to download)
   ${scriptname} --scandir     (Google Drive/ directory made by 'Google Backup and Sync' app, default: ${scandir})
   ${scriptname} --format      (pdf or office, default: ${format})
   ${scriptname} --out         (root outdir, default: ${outdir})
   ${scriptname} <in>          (gdrive export URLs + optional paths to download: "out" "https://..." "out/mydir" "https://...")

   example export url: https://docs.google.com/document/d/1234asdfASDF7890/export?format=pdf
   will not work with the sharing URL: https://drive.google.com/file/d/1234asdfASDF7890/view?usp=sharing
   because the type is not known.

   paths per URL aren't supported yet (only --out works)...
   dont use paths in the <in> list, only http(s):// args there...
   --scan wont generate them either.   you'll only get a flat list backed up...

   make sure your chrome browser can load urls pointing into your google drive account,
   we'll use chrome-remote-interface to automate your chrome, which has your session

   examples:
   ./gdown_chrome.js --scan --format doc --out "out_doc" --list       # list each doc from "~/Google Drive" folder as an export URL
   ./gdown_chrome.js --scan --format pdf --out "out_doc"              # download each doc from "~/Google Drive" folder as PDF format

   # download single document from given export URL (url will be changed to --format type)
   ./gdown_chrome.js --format doc --out "out_doc" "https://docs.google.com/document/d/1234asdfASDF7890/export?format=docx"
   ./gdown_chrome.js --format pdf --out "out_pdf" "https://docs.google.com/document/d/1234asdfASDF7890/export?format=docx"
   ./gdown_chrome.js --format pdf --out "out_pdf" "https://docs.google.com/document/d/1234asdfASDF7890/export?format=docx"
  ` );
}
let ARGC = process.argv.length-2; // 1st 2 are node and script name...
let ARGV = process.argv;
let non_flag_args = 0;
let non_flag_args_required = 0;
for (let i = 2; i < (ARGC+2); i++) {
  if (ARGV[i] == "--help") {
    usage();
    process.exit( -1 )
  }

  if (ARGV[i] == "--verbose") {
    VERBOSE=true
    continue
  }
  if (ARGV[i] == "--list") {
    LIST_ONLY=true;
    continue
  }
  if (ARGV[i] == "--scan") {
    use_scan=true;
    continue
  }
  if (ARGV[i] == "--scandir") {
    i+=1;
    scandir=ARGV[i]
    continue
  }
  if (ARGV[i] == "--out") {
    i+=1;
    outdir=ARGV[i]
    continue
  }
  if (ARGV[i] == "--format") {
    i+=1;
    format=ARGV[i]
    continue
  }
  if (ARGV[i].substr(0,2) == "--") {
    console.log( `Unknown option ${ARGV[i]}` );
    process.exit(-1)
  }

  args.push( ARGV[i] )
  VERBOSE && console.log( `Parsing Args: argument #${non_flag_args}: \"${ARGV[i]}\"` )
  non_flag_args += 1
}

// output help if they're getting it wrong...
if (non_flag_args_required != 0 && (ARGC == 0 || !(non_flag_args >= non_flag_args_required))) {
  (ARGC > 0) && console.log( `Expected ${non_flag_args_required} args, but only got ${non_flag_args}` );
  usage();
  process.exit( -1 );
}
//////////////////////////////////////////

// macos assumed.   todo support windows...
let chrome_exe="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
//let chrome_exe="c:\Program Files\Google Chrome\Chrome.exe";
scandir = lib.expandTilde( scandir );


let downloadUrls=args.map( r => lib.gdriveExportUrlChangeFormat( r, format ) ).filter( r => r != undefined );

if (use_scan) {
  let s = lib.readdirRecursiveSync( scandir );
  downloadUrls = downloadUrls.concat( s.map( f => lib.gdriveFileToExportURL( f, format ) ).filter( r => r != undefined ) )
}

if (downloadUrls.length == 0) {
  usage();
  process.exit( -1 )
}

console.log( "list export URLs" )
for (let a of downloadUrls) {
  console.log( a );
}

if (LIST_ONLY) {
  //console.log( "" )
  //console.log( "list sharing URLs" )
  //for (let a of downloadUrls) {
    //console.log( lib.getShareUrl( lib.getID( a ) ) );
    ////console.log( a );
  //}
  process.exit( -1 )
}

(async function () {
  console.log( "launching chrome" )
  let child;
  if (0) {
    // this never worked:
    console.log( "clear out last temp profile..." )
    spawnSync( "rm -rf /tmp/temp_chrome-profile", { stdio: 'inherit', shell: true });
    let cmd = `rsync -ahX --info=progress2 --ignore-errors --exclude 'Singleton*' --exclude 'Lock' --exclude 'Cache' --exclude 'Media Cache' "${lib.expandTilde("~/Library/Application\ Support/Google/Chrome/Default/")}"  /tmp/temp_chrome-profile`;
    console.log( `rsync` )
    console.log( `${cmd}` )
    spawnSync( cmd, { stdio: 'inherit', shell: true });
    spawnSync( "ls -l /tmp/chrome-profile/Cookies", { stdio: 'inherit', shell: true });
    spawnSync( `ls -l "/tmp/chrome-profile/Login Data"`, { stdio: 'inherit', shell: true });
    child = lib.exec( chrome_exe, [ "--remote-debugging-port=9227", "--profile-directory=\"Default\""/*, `--user-data-dir=${expandTilde( "~/Library/Application Support/Google/Chrome" )}`*/ , `--user-data-dir=/tmp/temp_chrome-profile` ] );
  }
  else {
    // just kill chrome, tabs will reopen, dont worry, be happy.
    spawnSync('pkill -f "Google Chrome"', { stdio: 'ignore', shell: true });
    child = lib.exec( chrome_exe, [ "--remote-debugging-port=9227"/*, "--profile-directory=\"Default\""*/ /*, `--user-data-dir=${expandTilde( "~/Library/Application Support/Google/Chrome" )}`*/ /*, `--user-data-dir=/tmp/temp_chrome-profile`*/ ] );
  }
  console.log( "chrome launched" )

  await lib.timeout( 2000 );

  console.log( "trying to connect" )
  let client;
  try {
    // Connect to Chrome
    client = await CDP({ port: 9227 });

    // Get the list of all targets (tabs)
    const { targetInfos } = await client.Target.getTargets();

    // new tab
    const { targetId } = await client.Target.createTarget({ url: 'about:blank' });
    await client.Target.activateTarget({ targetId });

    // Loop through all existing tabs (targets) and find 'about:blank' ones
    let closed_one = false;
    for (const target of targetInfos) {
      if (target.url === 'about:blank') {
        console.log(`Closing tab with ID: ${target.targetId}`);
        try {
          await client.Target.closeTarget({ targetId: target.targetId });
          client = await CDP({ port: 9227 });
          await client.Target.activateTarget({ targetId });
          closed_one = true;
        } catch (err) {
          console.error(`Error closing tab ${target.targetId}: ${err}`);
        }
      }
    }

    // Enable domains
    await client.Network.enable();
    await client.Page.enable();

    // Set download behavior
    lib.mkpath( outdir )
    await client.send('Page.setDownloadBehavior', {
      behavior: 'allow',
      downloadPath: lib.getAbsolutePath( outdir ),
    });

    client.on("Page.downloadWillBegin", (event) => {
      console.log("DOWNLOAD_STARTED");
    });

    async function doNext() {
      if (0 < downloadUrls.length) {
        // TODO: if (isSharingURL( downloadUrls[0] )) downloadUrls[0] = convertSharingToExportURL( examineSharingURL( shareUrl ) )

        // pop the next url off the front
        let url = lib.getExportUrl( lib.getType( downloadUrls[0] ), lib.getID( downloadUrls[0] ), format );
        console.log( `downloading: ${downloadUrls[0]} ${lib.getType( downloadUrls[0] )} ${lib.getID( downloadUrls[0] )} ${url}` )
        downloadUrls = downloadUrls.slice(1);
        if (url == null) {
          process.exit(-1)
        }
        isFileFound = true; // reset this
        await client.Page.navigate({ url: url });
        await client.Page.loadEventFired();
        console.log(`Download initiated. ${url}`);
        await doNext();
      } else {
        await client.close();
        await child.kill('SIGTERM'); // Send a termination signal
        process.exit( 0 );
      }
    }

    // we can call this on a sharing URL to see what filetype is it
    async function examineSharingURL(shareUrl) {
      // Navigate to the Google Drive sharing URL
      await Page.navigate({ url: shareUrl });
      await Page.loadEventFired(); // Wait until the page has fully loaded

      // Extract file type from the page
      const result = await Runtime.evaluate({
        expression: `
          (function() {
            const title = document.querySelector('title').innerText;
            if (title.includes('Google Docs')) {
              return 'document';
            } else if (title.includes('Google Sheets')) {
              return 'spreadsheet';
            } else if (title.includes('Google Slides')) {
              return 'presentation';
            } else {
              return 'undefined';
            }
          })()
        `
      });
      return result.result.value; // This will return the inferred file type
    }

    client.on("Page.downloadProgress", async (event) => {
      if (event.state == "completed") {
        console.log("DOWNLOAD_COMPLETED");
        await doNext();
      }
    });
    client.Network.responseReceived((params) => {
      const { response, request } = params;
      const contentDisposition = params.response.headers['content-disposition'];
      if (contentDisposition && contentDisposition.includes('attachment')) {
        const matches = contentDisposition.match(/filename="([^"]+)"/);
        if (matches && matches[1]) {
          const filepath = path.join(outdir, matches[1]);
          console.log(` o  File incoming: "${matches[1]}"`);          
          if (fs.existsSync(filepath)) {
            console.log(` o  Destination exists: ${filepath}`);
          }
        }
      }

      //console.log( "status: ", response.status )
      if (response.status === 404 && (request.url.includes('drive.google.com') || request.url.includes('docs.google.com'))) {
        isFileFound = false;
        console.log('Error: File Not Found!');
      }
    });

    // Navigate to the download URL
    await doNext();

    // wait.   we'll close the app when downloads are done
    while (1) {
      await lib.timeout( 10000 );
    }
  } catch (err) {
    console.error('Error:', err);
    child.kill('SIGTERM'); // Send a termination signal
  } finally {
    if (client) {
      await client.close();
      await child.kill('SIGTERM'); // Send a termination signal
    }
  }
})();
