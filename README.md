# Print Google Slides deck to a book

Prepare a PDF format slidedeck for book printing
- add safe margins
- resize to destination size/DPI
- expand to destination aspect ratio


## REQUIREMENTS

- This is tested on MacOS BigSur under the terminal
- ImageMagick
- Python


## HOWTO

You'll need:
- Google Slides - Slide Deck
  - or any app that exports PDF
- A Book Publishing service that accepts PDF upload
  - like https://www.prestophoto.com/
- This script, which prepares your PDF for book printing.

How to prepare your book PDF for upload:
- Create your Slide Deck close to the dimensions you'll want
  - Under: `Google Slides / <your deck> / File / Page Setup`
- Export to PDF from Google Slides
  - Under: `Google Slides / <your deck> / File / Download / PDF Document (.pdf)`
- Configure the script
  - For now, the settings are at the top of the `pdf_slidedeck2book.sh` file.
  - Configure your BOOK_WIDTH, BOOK_HEIGHT, DPI
- Run the script:
  - `pdf_slidedeck2book.sh <DownloadedPDF>.pdf`
  - Wait....   (it can be very slow if you have a lot of pages/graphics)
  - New pdf file outputs next to your original one: `<original filename>-YYYYMMDD-TTTTTT.pdf`

Upload the new PDF to your book publishing service

