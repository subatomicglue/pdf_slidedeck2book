#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { PDFDocument, rgb } = require('pdf-lib');


// this script's dir (and location of the other tools)
let scriptpath=__filename  // full path to script
let scriptname=__filename.replace( /^.*\//, "" )  // name of script w/out path
let scriptdir=__dirname    // the dir of the script
let cwd=process.cwd()

// options:
let args = [];
let VERBOSE=false;
let aspect_x
let aspect_y
let margin_x=0
let margin_y=0
let dpi=300
let color="auto" // can be "auto" or { r: 255, g: 255, b: 255 }  (0-255 range)
function isNumericString(value) {
  return typeof value === "string" && !isNaN(value) && !isNaN(parseFloat(value));
}
let colorFuncs = {
  "auto": getColor_TopLeftPixel,
  "pixel": getColor_TopLeftPixel,
  "avg": getColor_Avg,
}

/////////////////////////////////////
// scan command line args:
function usage()
{
  console.log( `${scriptname} - change size + aspect ratio + margins + dpi of a pdf - give a new aspect ratio, increases the pdf width or height and fills the expanded margins with color matching that page` );
  console.log( `Usage:
   ${scriptname} --help        (this help)
   ${scriptname} --verbose     (output verbose information)
   ${scriptname} --dpi 300     (number of dots per aspect_x and y e.g. 75, 150, 300, 600, etc... resulting pdf units will be apect_x * dpi)
   ${scriptname} --aspect x y  (number of units wide and high  e.g. 16 9, 4 3, etc...)
   ${scriptname} --margin x y  (enforce a margin, in terms of units  e.g. 0.2 0.2)
   ${scriptname} --color auto  (margin color, auto (topleft pixel), avg (average of all pixels), or give r g b (0-255))
   ${scriptname} <in...>       (pdf filenames as input,
                                each output pdf will be same filename,
                                if collision then filename-adjusted.pdf")

   Examples:
    ${scriptname} --color avg --aspect 16 10 --margin 0.2 0.2 --dpi 300 myfile.pdf
    ${scriptname} --color auto --aspect 16 10 --margin 0.2 0.2 --dpi 300 myfile.pdf
    ${scriptname} --color 33 33 33 --aspect 16 10 --margin 0.2 0.2 --dpi 300 myfile.pdf
  ` );
}
const ARGC = process.argv.length-2; // 1st 2 are node and script name...
const ARGV = process.argv;
let non_flag_args = 0;
const non_flag_args_required = 1;
for (let i = 2; i < (ARGC+2); i++) {
  if (ARGV[i] == "--help") {
    usage();
    process.exit( -1 )
  }

  if (ARGV[i] == "--verbose") {
    VERBOSE=true
    continue
  }
  if (ARGV[i] == "--aspect") {
    i+=1;
    aspect_x=ARGV[i]
    i+=1;
    aspect_y=ARGV[i]
    console.log( `setting aspect ${aspect_x}x${aspect_y}` )
    continue
  }
  if (ARGV[i] == "--margin") {
    i+=1;
    margin_x=ARGV[i]
    i+=1;
    margin_y=ARGV[i]
    console.log( `setting margin ${margin_x}x${margin_y}` )
    continue
  }
  if (ARGV[i] == "--dpi") {
    i+=1;
    dpi=ARGV[i]
    console.log( `setting dpi ${dpi}` )
    continue
  }
  if (ARGV[i] == "--color") {
    i+=1;
    let first_value=ARGV[i]
    if (!isNumericString( first_value )) {
      color = first_value
      if (!(color in colorFuncs)) {
        console.log( `setting color`, color, "is not a valid operator.  Valid: ", Object.keys( colorFuncs ) )
        process.exit( -1 )
      }
    } else {
      color = {}
      color.r=isNumericString( first_value ) ? first_value : 255
      i+=1;
      color.g=isNumericString( ARGV[i] ) ? ARGV[i] : 255
      i+=1;
      color.b=isNumericString( ARGV[i] ) ? ARGV[i] : 255
    }
    console.log( `setting color`, color )
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


function gcd(a, b) {
  while (b !== 0) {
    let temp = b;
    b = a % b;
    a = temp;
  }
  return a;
}

function getAspect( width, height ) {
  const gcdValue = gcd(width, height);
  const smallestNumerator = width / gcdValue;
  const smallestDenominator = height / gcdValue;
  return { width, height, aspect_x: smallestNumerator, aspect_y: smallestDenominator, aspect: width/height }
}

async function getAspectOfPDF(infile) {
  // Load existing PDF
  const existingPdfBytes = fs.readFileSync(infile);
  const pdfDoc = await PDFDocument.load(existingPdfBytes);

  // Get the first page
  for (let pageIt = 0; pageIt < pdfDoc.getPages().length; ++pageIt) {
    const page = pdfDoc.getPages()[pageIt];
    const currentWidth = page.getWidth();
    const currentHeight = page.getHeight();
    const currentAspect = currentWidth/currentHeight;
    return getAspect( currentWidth, currentHeight )
  }
  return undefined
}

function getColor_TopLeftPixel(filename, pageNumber = 0) {
  const command = `magick -colorspace sRGB "${filename}[${pageNumber}]" -format "%[fx:int(255*p{1,1}.r)],%[fx:int(255*p{1,1}.g)],%[fx:int(255*p{1,1}.b)]" info:`;

  try {
    // Execute the command and capture the output
    const output = execSync(command).toString().trim();
    const [r, g, b] = output.split(',').map(val => parseInt(val, 10));

    // Return the color as an object with r, g, b values
    return { r, g, b };
  } catch (error) {
    console.error('Error executing magick command:', error);
    return null;
  }
}

function getColor_Avg(filename, pageNumber = 0) {
  const command = `magick -colorspace sRGB "${filename}[${pageNumber}]" -resize 1x1\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info:-`;

  try {
    // Execute the command and capture the output
    const output = execSync(command).toString().trim();
    const [r, g, b] = output.split(',').map(val => parseInt(val, 10));

    // Return the color as an object with r, g, b values
    return { r, g, b };
  } catch (error) {
    console.error('Error executing magick command:', error);
    return null;
  }
}


async function scaleAllPagesWithMargin(inputFile, outputFile, newWidth, newHeight, minMarginX, minMarginY, color="auto") {
  // Load the existing PDF
  const existingPdfBytes = fs.readFileSync(inputFile);
  const pdfDoc = await PDFDocument.load(existingPdfBytes);

  // Create a new PDF to store the scaled pages
  const newPdfDoc = await PDFDocument.create();

  // Calculate the **available space** after applying the minimum margin
  const availableWidth = newWidth - 2 * minMarginX;
  const availableHeight = newHeight - 2 * minMarginY;

  // Loop through each page and scale it
  for (let i = 0; i < pdfDoc.getPageCount(); i++) {
    const originalPage = pdfDoc.getPages()[i]; // Get the original page
    const embeddedPage = await newPdfDoc.embedPage(originalPage); // Embed the page properly

    // Get original dimensions
    const currentWidth = originalPage.getWidth();
    const currentHeight = originalPage.getHeight();
    const currentAspect = currentWidth/currentHeight;

    // Calculate scale factors based on available space (after margin)
    const scaleX = availableWidth / currentWidth;
    const scaleY = availableHeight / currentHeight;

    // Choose the smaller scale factor to maintain aspect ratio
    const scaleFactor = Math.min(scaleX, scaleY);

    // Calculate the final scaled width and height
    const scaledWidth = currentWidth * scaleFactor;
    const scaledHeight = currentHeight * scaleFactor;

    // Calculate the centered position inside the available space
    const xOffset = (newWidth - scaledWidth) / 2;
    const yOffset = (newHeight - scaledHeight) / 2;

    // Create a new page with the desired size
    const newPage = newPdfDoc.addPage([newWidth, newHeight]);

    const scaled_x = Math.max(xOffset, minMarginX)
    const scaled_y = Math.max(yOffset, minMarginY)
    const scaled_width = scaledWidth
    const scaled_height = scaledHeight

    // Draw the original page onto the new page, scaled and respecting margins
    newPage.drawPage(embeddedPage, {
      x: scaled_x, // Ensure minimum left/right margin
      y: scaled_y, // Ensure minimum top/bottom margin
      width: scaled_width,
      height: scaled_height,
    });

    // { r: 255, g: 255, b: 255 }
    let margin_color = (typeof color === "object") ? color : colorFuncs[color] ? colorFuncs[color](inputFile, i) : { r: 255, g: 255, b: 255 }

    // output stats for this page
    const currentA = getAspect( currentWidth, currentHeight )
    const newA = getAspect( newWidth, newHeight )
    console.log( `[${path.basename(inputFile)}] Page ${i} : `, currentAspect, currentWidth, currentHeight, `${currentA.aspect_x}x${currentA.aspect_y}`, " : ", newA.aspect, newWidth, newHeight, `${newWidth/dpi}x${newHeight/dpi}`, " : ", margin_color )


    // margin color - rectangle fills (0,0 is lower left corner)
    let tol=1;

    // bottom
    newPage.drawRectangle({
      x: scaled_x,
      y: 0,
      width: scaled_width+tol,
      height: scaled_y+tol,
      color: rgb(margin_color.r/255, margin_color.g/255, margin_color.b/255),
    });
    // top
    newPage.drawRectangle({
      x: scaled_x,
      y: scaled_y + scaled_height-tol,
      width: scaled_width+tol,
      height: scaled_y+tol,
      color: rgb(margin_color.r/255, margin_color.g/255, margin_color.b/255),
    });

    // left
    newPage.drawRectangle({
      x: 0,
      y: 0,
      width: scaled_x+tol,
      height: newHeight,
      color: rgb(margin_color.r/255, margin_color.g/255, margin_color.b/255),
    });
    // right
    newPage.drawRectangle({
      x: scaled_x + scaled_width-tol,
      y: 0,
      width: scaled_x+tol,
      height: newHeight,
      color: rgb(margin_color.r/255, margin_color.g/255, margin_color.b/255),
    });

  }

  // Save the modified PDF
  console.log( `Writing ${outputFile}` );
  const pdfBytes = await newPdfDoc.save();
  fs.writeFileSync(outputFile, pdfBytes);
}

(async () => {
  if (aspect_x == undefined || aspect_y == undefined) {
    usage()
    console.log( "Must provide aspect ratio" );
    process.exit( -1 );
  } else {
    for (let infile of args) {
      let outfile_base = path.basename(infile, path.extname(infile))
      if (fs.existsSync( outfile_base + ".pdf" )) {
        outfile_base += "-adjusted.pdf"
      } else {
        outfile_base += ".pdf"
      }

      //await drawRectangleOnPDF(infile, outfile_base, aspect_x, aspect_y);
      await scaleAllPagesWithMargin(infile, outfile_base, aspect_x * dpi, aspect_y * dpi, margin_x * dpi, margin_y * dpi, color);
    }
  }
})()

