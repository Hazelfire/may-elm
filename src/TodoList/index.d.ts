// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports

export namespace Elm {
  namespace TodoList {
    export interface App {
      ports: {
        setLocalStorage: {
          subscribe(callback: (data: unknown) => void): void
        }
        setFocus: {
          subscribe(callback: (data: string) => void): void
        }
        openStripe: {
          subscribe(callback: (data: string) => void): void
        }
      };
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: { authCode: string | null; authTokens: unknown | null; fs: unknown | null; offset: string; appVariables: { apiBackendUrl: string; authBase: string; clientId: string; redirectUri: string; serviceCost: string } };
    }): Elm.TodoList.App;
  }
}