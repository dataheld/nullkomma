import click


def greeting() -> str:
    return "Hello from Python"


@click.command()
def main() -> None:
    click.echo(greeting())
