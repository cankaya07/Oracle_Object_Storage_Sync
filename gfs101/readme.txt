Goetz's File Splitter
Copyright 1999 Lawrence Goetz
goetz@lawrencegoetz.com
http://www.lawrencegoetz.com

VERSION 1.01

*************
Introduction:
*************

Goetz's File Splitter is freeware. If you find it to be of use to you,
please send me e-mail letting me know.

This a command line program that runs in Windows 95, 98, NT or higher. 
It will not work in DOS mode.

Goetz's File Splitter is a program designed to take a file and split it up 
into smaller pieces. This is useful for taking a file that can not fit on 
one floppy and then splitting it on many floppies. It can also be used where 
you are limited in file size, such as in e-mail attachments. Some services 
limit the file size of an attachment. You can now send the large file as 
many smaller attachments. Goetz's File Splitter will also create a batch 
file that will restore the split file.

Goetz's File Splitter should not be used as a backup program, because in 
the event the restore does not work, your original would be lost. The file
being split is only being read and is not changed. However should Windows
lock up, something could go wrong. In any event, I'm not responsible for
any damage that could go wrong by using this program. It's best to make
a copy of any file you're spliting to prevent any such problems.

*************
Instructions:
*************

It is a command line program (DOS prompt). It's file name is: gfsplit
I recommend you copy it to your c:\ directory or place it's directory in 
your path statement. This way you can run the file in whatever directory you 
are in.


SPLITTING:

You run Goetz's File Splitter as follows:
gfsplit source destination size

source - the file to be split
destination - the names of the split files
size - The size in K for the split files. I use K to mean 1000, not 1024.

You will get an error if the source file does not exist, or if you leave off 
any of the command line arguments. Also if the split size is invalid, such
as larger than the source file's size, you'll get an error.

Example:
gfsplit mygame.zip mygame 1440

This will take a file called mygame.zip and split it into a series of files
mygame1, mygame2, ..., mygamen. Each file will be up to 1440K, the last file 
will be the slack of 1440K. It will create a restore file mygame.bat that 
will be used to restore the file.

You can now copy the split files and the restore file to floppies or send 
them over the internet as attached files. In Windows 95 you can easily send 
them all to the floppy drive with one command. First you go to Windows 
Explorer and highlight them all with the mouse. Then choose from the File 
menu: Send To, Floppy. It will prompt you to insert the next disk when the 
disk is full.

RESTORING:

To restore a file, copy all of it's split files and it's restore file to a 
single directory on your hard drive. Now you can run the restore file and it 
will combine the split files. If a split file is missing you will get an 
error message and the listing of the missing files.

If you are using Windows Explorer to copy your split files from your disks: 
After swapping disks, press F5 to get the new disk's contents.

To restore the example file mygame.zip, you would run mygame.bat. This will 
recreate the file mygame.zip in your directory. You will get an error 
message if the file mygame.zip already exists.

You can restore to another path by specifing it as a command line argument
to the restore file. To restore the file to c:\games\mygame do

mygame c:\games\mygame\
You must end the path with a \ or you will create a file called 
c:\games\mygamemygame


I hope you find this program to be of some use to you.

Changes since 1.0:
Fixed null end of string problem for Windows NT.

Changes since .92:
None.

Fixed from version .91:
Problem with a split size larger than the input size. 
It would work for a requested size larger than the input size. However
if the size was very large the system would run out of memory.
Also I didn't check for negitive or zero split size.

Fixed from version .90:
Had problem with files in paths, it would store path info that would
make it restore to the original location.
Now works with restoring to any location.
Fixed problem with some people not able to restore because the first file
would not copy correctly.

Thank you,

Lawrence Goetz
goetz@lawrencegoetz.com
___________________________________________________________________________
Microsoft Windows is a trademark of Microsoft Corporation.