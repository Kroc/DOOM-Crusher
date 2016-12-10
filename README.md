# DOOM Crusher #

Shrinks DOOM resource files: PK3s (ZIP files), WADs, PNGs & JPGs.

![DOOM Crusher Icon](icon.png)

Simply drag-n-drop any file, folder, or multiple-selection thereof on top of the "doom-crusher.bat" file and DOOM Crusher will recursively optimize anything it can recognise.

## Methodolody ##

JPEG files are optimized using ["jpegtran"][1]:

> jpegtran works by rearranging the compressed data (DCT coefficients), without ever fully decoding the image.  Therefore, its transformations are lossless: there is no image degradation at all ...

The `-optimize` parameter is used to "perform optimization of entropy encoding parameters" which can shrink the file without changing the actual image at all.

PNG files are run through a battery of optimizers:

* [OptiPNG][2]
* [PNGOUT][3] (not included in the download due to licence restrictions)
* [Pngcrush][4]
* [DeflOpt][5] (binary included due to original website going offline)

WAD files are first optimized by [WADPTR][6]:

> WADPTR uses three seperate methods to compress WAD files: lump
merging, graphic squashing and sidedef packing. These actually
all work in quite similar ways. As well as compressing WADs, it
also removes unused data in WADs (information that exists but is
not part of any lump) and removes unused sidedefs (sidedefs that
exist but are not bound to any linedef).

WADs are then scanned for PNG and JPEG files and optimized as above.

[1]: http://jpegclub.org/jpegtran/
[2]: http://optipng.sourceforge.net/
[3]: http://advsys.net/ken/utils.htm
[4]: http://pmt.sourceforge.net/pngcrush/
[5]: https://web.archive.org/web/20140209022101/http://www.walbeehm.com/download/
[6]: https://soulsphere.org/projects/wadptr/