# Configuration

[Documentation index](./index.md)

## Configuration files

The Microsoft C++ Language Server uses the following configuration files:

1. `.github/lsp.json` [configures GitHub Copilot CLI](https://github.com/github/copilot-cli?tab=readme-ov-file#-configuring-lsp-servers) to use the Microsoft C++ Language Server for C++ files, and sets the command line arguments passed to `mscppls`. The plugin supplies a server definition; use this project-level file to customize it.
2. `.mscppls/cpp-lsp.json` is optional and sets the path to the project root and the path to the `compile_commands.json` file. `repositoryPath` and `compileCommands` can be relative or absolute paths. If relative, they are resolved relative to the directory containing `cpp-lsp.json`. By changing the `--lsp-config` argument in `.github/lsp.json`, `cpp-lsp.json` can be stored at any user-defined path. `version` must always be `1`.
3. [`compile_commands.json` specifies the command line to build each target](https://clang.llvm.org/docs/JSONCompilationDatabase.html) in the project. Details for how to generate this file depend on the build system the project uses. See [generating compile commands](./compile-commands.md) for build-system-specific guidance.

By default, logs are stored in a session-specific directory at `$TEMP/mscppls/<session-id>/logs`. Workspace caches are stored in workspace-specific subdirectories under `%LOCALAPPDATA%\mscppls` on Windows or `~/.mscppls` on macOS and Linux. The log directory can be overridden with the `--log-dir` argument.

## Customizing Copilot CLI launch flags

To customize the command-line flags that GitHub Copilot CLI passes to the Microsoft C++ Language Server, edit [`.github/lsp.json`](https://github.com/github/copilot-cli?tab=readme-ov-file#-configuring-lsp-servers).

The server can be launched with additional flags using either:

- `npx @microsoft/cpp-language-server [additional flags]`
- `mscppls [additional flags]` (if installed globally via npm)

If you install the package globally, npm adds the `mscppls` executable to your `PATH`.

See the [command line reference](./command-line-options.md) for available flags.

## Startup working directory

The plugin sets its LSP launch directory to `${COPILOT_SESSION_CWD}`, which requires a Copilot CLI build that supplies the session working directory during server launch. It does not substitute the Git root or plugin installation directory.

With an MSCPPLS build that supports `MSCPPLS_WORKING_DIRECTORY`, set it before starting Copilot CLI to override the server's inherited working directory:

```powershell
$env:MSCPPLS_WORKING_DIRECTORY = 'C:\repo\apps\demo'
```

Only an existing directory that the server can enter takes effect. Unset, empty, nonexistent, or file-valued settings leave the CLI-selected directory unchanged. Relative values resolve against that directory. Restart the server after changing the variable.

Explicit `--workspace-config` and `auto_configure_directory` settings retain their existing precedence. The variable does not change the client workspace used for indexing or enable automatic MSBuild extraction.

## Minimal configuration (automatic discovery)

If you omit the `--lsp-config` argument (or pass `--allow-missing-lsp-config`), the language server automatically searches its startup working-directory cone for a single `compile_commands.json`. The client workspace still determines the indexing scope. In this mode you don't need a `cpp-lsp.json` file or a `repositoryPath`:

```json
{
  "lspServers": {
    "cpp": {
      "command": "mscppls",
      "args": [],
      "cwd": "${COPILOT_SESSION_CWD}",
      "fileExtensions": {
        ".cpp": "cpp",
        ".c": "cpp",
        ".h": "cpp",
        ".hpp": "cpp"
      },
      "requestTimeoutMs": 1000000
    }
  }
}
```

This example uses the [global npm installation](./installation.md#npm). For an `npx` launch, use `"command": "npx"` and `"args": ["@microsoft/cpp-language-server"]` instead.

The discovered configuration is cached, so later startups skip the search. Discovery fails if no `compile_commands.json` is found or if more than one is found; in that case, use an explicit `cpp-lsp.json`.

## Indexing settings

See [indexing](./indexing.md) for exclude patterns and additional browse directories. To turn off semantic symbol indexing for all repositories, see [disabling WCI](./indexing.md#disabling-wci), which uses the per-user state file rather than project configuration.