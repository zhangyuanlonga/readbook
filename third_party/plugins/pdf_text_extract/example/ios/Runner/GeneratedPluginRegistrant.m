//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<pdf_text_extract/PdfTextPlugin.h>)
#import <pdf_text_extract/PdfTextPlugin.h>
#else
@import pdf_text_extract;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
  [PdfTextPlugin registerWithRegistrar:[registry registrarForPlugin:@"PdfTextPlugin"]];
}

@end
