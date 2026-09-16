# Contributing

Contributions are welcome! Here's how you can help:

## Issues

Found a bug or have a feature request? Please open an issue with:
- Clear description of the problem
- Steps to reproduce (if applicable)
- Your environment (OS, Scalingo region, FrankenPHP version)
- Expected vs. actual behavior

## Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test with your FrankenPHP app on Scalingo
5. Commit with clear messages
6. Push and open a pull request

## Testing

To test the buildpack locally:

1. Add `.buildpacks` pointing to your local fork
2. Deploy to Scalingo: `git push scalingo main`
3. Check deployment logs: `scalingo logs --follow`

## Code Style

- Shell scripts should be readable and well-commented
- Follow existing formatting conventions
- Document any new features in README.md

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
