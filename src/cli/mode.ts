export function shouldStartMcpServer(argv: readonly string[]): boolean {
  return argv.length <= 2;
}
