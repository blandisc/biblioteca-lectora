// Abre o cierra el iPhone Duo del simulador sin tocar Device Hub.
//
// SpringBoard trae un servicio de pruebas (SBSDisplayToolService, «com.apple.springboard.sbdisplay»)
// que mueve la bisagra como si la doblaras con la mano; esta herramienta lo llama con las mismas
// opciones que su ayuda interna (SBFDisplayToolSwapSettingsFromArguments).
//
// Se compila para el simulador con el permiso del servicio dentro del binario (sección
// __TEXT,__entitlements, como Xcode hace con las apps del simulador) y se corre con
// `xcrun simctl spawn`. Lo hace scripts/duo-estudio.sh; a mano:
//
//   xcrun simctl spawn <udid> /ruta/duopose -position=open -duration=0 -wait
//   xcrun simctl spawn <udid> /ruta/duopose -position=closed -deviceOrientation=portrait -duration=0 -wait
//
// Opciones: -position=closed|book|open|0.0-1.0, -duration=<segundos> (0: al instante),
// -deviceOrientation=portrait|landscapeLeft|…, -fade | -continuous, -wait.
// La pose se queda hasta la siguiente llamada: sobrevive a cerrar y abrir la app.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>

// Lo que lee SBFDisplayToolSwapSettingsFromArguments (64 bytes, `{?=qdqqBqdd}` en el runtime).
typedef struct {
    long long targetMode;
    double duration;
    long long deviceOrientation;
    long long profileOverride;
    BOOL waitForCompletion;
    long long hasTargetPosition;
    double targetHingePosition;
    double reserved;
} SwapSettings;

typedef BOOL (*SettingsFromArguments)(NSArray *, SwapSettings *, NSError **);

int main(int argc, char **argv) {
    @autoreleasepool {
        dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
        dlopen("/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation", RTLD_NOW);
        SettingsFromArguments parse = (SettingsFromArguments)dlsym(RTLD_DEFAULT, "SBFDisplayToolSwapSettingsFromArguments");
        Class serviceClass = NSClassFromString(@"SBSDisplayToolService");
        if (!parse || !serviceClass) {
            fprintf(stderr, "duopose: este simulador no tiene la bisagra (¿no es un iPhone Duo?)\n");
            return 4;
        }
        NSMutableArray *arguments = [NSMutableArray array];
        for (int i = 1; i < argc; i++) [arguments addObject:@(argv[i])];

        SwapSettings settings;
        memset(&settings, 0, sizeof settings);
        NSError *error = nil;
        if (!parse(arguments, &settings, &error)) {
            fprintf(stderr, "duopose: %s\n", error.localizedDescription.UTF8String ?: "opciones no válidas");
            return 2;
        }

        id service = [[serviceClass alloc] init];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block int status = 0;
        void (^reply)(NSError *) = ^(NSError *failure) {
            if (failure) {
                fprintf(stderr, "duopose: SpringBoard no cambió la pose: %s\n", failure.description.UTF8String);
                status = 1;
            }
            dispatch_semaphore_signal(done);
        };
        ((void (*)(id, SEL, SwapSettings, id))objc_msgSend)(service, NSSelectorFromString(@"swapDisplayWithSettings:completionHandler:"),
                                                           settings, reply);
        if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC))) {
            fprintf(stderr, "duopose: SpringBoard no contestó en 20 s\n");
            status = 3;
        }
        ((void (*)(id, SEL))objc_msgSend)(service, NSSelectorFromString(@"invalidate"));
        return status;
    }
}
