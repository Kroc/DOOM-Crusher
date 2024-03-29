# DOOM Crusher #

Shrinks DOOM resource files: PK3s (ZIP files), WADs, PNGs & JPGs, although can be used as a general-purpose PNG & ZIP optimizer.

![DOOM Crusher Icon](icon.png)

Simply drag-n-drop any file, folder, or multiple-selection thereof on top of the "doom-crusher.bat" file and DOOM Crusher will recursively optimize anything it can recognise.

Supported file-types:

* JPEG & PNG images
* ".wad" & ".iwad" files
* ".pk3" & ".ipk3" files (most modern DOOM engines)
* ".pke" ([Eternity])
* ".epk" ([EDGE] / 3DGE)
* ".kart" ([Sonic Robo Blast 2 Kart][SRB2Kart])

[Eternity]: https://github.com/team-eternity/eternity
[EDGE]: https://doomwiki.org/wiki/EDGE
[SRB2Kart]: https://mb.srb2.org/showthread.php?p=802727

In addition, ZIP files will be recompressed maximally, but won't be unpacked and recursed as with PK3 & WAD files.

For bugs, suggestions and feedback please either file an issue on the [GitHub](https://github.com/Kroc/DOOM-Crusher/issues) page or mail kroc@camendesign.com

<!--
## Samples: ##
(needs updating for v3.0)

| WAD                 |   Original (B) | (MB)     |   Crushed (B) | (MB)     |    Delta
|---------------------|---------------:|---------:|--------------:|---------:|----------:
| [boa_c1.pk3][A]     |  373,344,372 B | 356.0 MB | 300,256,005 B | 286.3 MB | -69.06 MB
| [DUMP-3.PK3][B]     |   74,526,263 B |  71.0 MB |  68,149,144 B |  64.9 MB |  -6.08 MB
| [brutalv20b.pk3][C] |   37,046,275 B |  35.3 MB |  36,379,722 B |  34.7 MB |  -0.64 MB

[A]: http://boa.realm667.com/
[B]: http://forum.zdoom.org/viewtopic.php?f=19&t=52276&sid=1cdc5a0e07f76597c907dc82b9679339&start=1335
[C]: http://www.moddb.com/mods/brutal-doom
-->

## Methodology ##

- JPEG files are optimized using [jpegtran]:

  > jpegtran works by rearranging the compressed data (DCT coefficients), without ever fully decoding the image. Therefore, its transformations are lossless: there is no image degradation at all ...

- PNG files are run through [oxipng], a multi-threaded PNG optimiser written in Rust. This replaces OptiPNG, PNGCrusher and PNGout used in v2.x

[jpegtran]: http://jpegclub.org/jpegtran/
[oxipng]: https://github.com/shssoichiro/oxipng

<!--
WAD files are first optimized by [WADptr]:

[wadptr]: https://soulsphere.org/projects/wadptr/

> WADptr uses three separate methods to compress WAD files: lump merging, graphic squashing and side-def packing. These actually all work in quite similar ways. As well as compressing WADs, it also removes unused data in WADs (information that exists but is not part of any lump) and removes unused side-defs (side-defs that exist but are not bound to any line-def).

Side-def packing is not used by DOOM-Crusher due to graphical glitches that may occur in certain WADs.
-->

- WADs are <!--then--> scanned for PNG and JPEG lumps and optimized as above

- PK3 files are the WAD format used by modern DOOM engines. A PK3 file is just a renamed ZIP file. The file is unpacked and the contents are optimized as above (PK3 files can contain WAD files, which themselves can contain PNG & JPEG files).

  After the contents have been optimized, the PK3 file is repacked using [7Zip]'s superior ZIP compression (not to be confused with the ".7z" format). Finally, the PK3 file is run through [AdvZip] to shave the last few KB off.

[7zip]: http://www.7-zip.org/
[advzip]: https://github.com/amadvance/advancecomp

## Caveats & Things to Consider ##

* You should not run DOOM Crusher on your development-copy of your PK3/WAD. Whilst DOOM Crusher is designed to optimize "losslessly", it may remove 'unused' resources from WADs which you may be storing for later use. It's best to run DOOM Crusher on a final copy of your project before you test it and upload it for distribution

* DOOM Crusher is crushingly slow. It aims for maximum compression, not speed. The number of PNG files determines run time and thousands of PNGs may take on the order of _days_ to compress!
  
  Results are cached, so a file that's already been compressed will not be attempted again