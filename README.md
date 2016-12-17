# DOOM Crusher #

Shrinks DOOM resource files: PK3s (ZIP files), WADs, PNGs & JPGs.

![DOOM Crusher Icon](icon.png)

Simply drag-n-drop any file, folder, or multiple-selection thereof on top of the "doom-crusher.bat" file and DOOM Crusher will recursively optimize anything it can recognise.

For bugs, suggestions and feedback please either file an issue on the [GitHub](https://github.com/Kroc/DOOM-Crusher/issues) page or mail kroc+doom@camendesign.com

## Samples: ##

| WAD                 |   Original (B) | (MB)     |   Crushed (B) | (MB)     |    Delta
|---------------------|---------------:|---------:|--------------:|---------:|----------:
| [boa_c1.pk3][A]     |  373,344,372 B | 356.0 MB | 300,256,005 B | 286.3 MB | -69.06 MB
| [DUMP-3.PK3][B]     |   74,526,263 B |  71.0 MB |  68,149,144 B |  64.9 MB |  -6.08 MB
| [brutalv20b.pk3][C] |   37,046,275 B |  35.3 MB |  36,379,722 B |  34.7 MB |  -0.64 MB

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

> WADPTR uses three seperate methods to compress WAD files: lump merging, graphic squashing and sidedef packing. These actually all work in quite similar ways. As well as compressing WADs, it also removes unused data in WADs (information that exists but is not part of any lump) and removes unused sidedefs (sidedefs that exist but are not bound to any linedef).

WADs are then scanned for PNG and JPEG files and optimized as above.

PK3 files are the WAD format used by modern DOOM engines. A PK3 file is just a renamed ZIP file. The file is unpacked and the contents are optimized as above (PK3 files can contain WAD files, which themselves can contain PNG & JPEG files).

After the contents have been optimized, the PK3 file is repacked using [7Zip][7]'s superior ZIP compression (not to be confused with the ".7z" format). Finally, the PK3 file is run through DeflOpt to shave the last few KB off.

## Caveats & Things to Consider ##

* You should not run DOOM Crusher on your development-copy of your PK3/WAD. Whilst DOOM Crusher is designed to optimize "losslessly", it may remove 'unused' resources from WADs which you may be storing for later use. It's best to run DOOM Crusher on a final copy of your project before you test it and upload it for distribution

* DOOM Crusher is slow. A 300+ MB project may take 3 to 7 hours to crush depending on your CPU


[1]: http://jpegclub.org/jpegtran/
[2]: http://optipng.sourceforge.net/
[3]: http://advsys.net/ken/utils.htm
[4]: http://pmt.sourceforge.net/pngcrush/
[5]: https://web.archive.org/web/20140209022101/http://www.walbeehm.com/download/
[6]: https://soulsphere.org/projects/wadptr/
[7]: http://www.7-zip.org/

[A]: http://boa.realm667.com/
[B]: http://forum.zdoom.org/viewtopic.php?f=19&t=52276&sid=1cdc5a0e07f76597c907dc82b9679339&start=1335
[C]: http://www.moddb.com/mods/brutal-doom