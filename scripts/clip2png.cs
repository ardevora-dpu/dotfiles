// clip2png.cs - minimal clipboard-to-PNG helper.
// Compile: csc.exe /optimize /target:exe /out:clip2png.exe clip2png.cs
// Exit codes:
//   0 = success
//   1 = no output path provided
//   2 = no image in clipboard
//   3 = failed to get image from clipboard
//   4 = failed to save image

using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Forms;

class ClipboardToPng {
    [STAThread]
    static int Main(string[] args) {
        if (args.Length < 1) {
            Console.Error.WriteLine("Usage: clip2png.exe <output-path>");
            return 1;
        }

        if (!Clipboard.ContainsImage())
            return 2;

        try {
            using (var img = Clipboard.GetImage()) {
                if (img == null)
                    return 3;

                var dir = Path.GetDirectoryName(args[0]);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                img.Save(args[0], ImageFormat.Png);
            }
            return 0;
        }
        catch (Exception ex) {
            Console.Error.WriteLine("Error: " + ex.Message);
            return 4;
        }
    }
}
