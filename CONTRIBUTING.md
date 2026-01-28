# Contributing to GameLog

Thank you for your interest in contributing to GameLog! We're excited to have you join our community of developers building the ultimate gaming platform.

## 🎯 Our Mission

GameLog aims to be the **Letterboxd for video games** - a social platform where gamers can track, rate, review, and discover games. We believe in collaborative development and keeping the project free and open source.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Git
- A code editor (VS Code, Android Studio, etc.)

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/GameLog.git
   cd GameLog
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

4. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📋 Types of Contributions

### 🐛 Bug Fixes
- Check existing issues first
- Create a clear bug report if needed
- Include steps to reproduce
- Test your fix thoroughly

### ✨ New Features
- Open an issue to discuss the feature first
- Follow existing code patterns
- Update documentation
- Add tests if applicable

### 📚 Documentation
- Improve README, comments, or guides
- Fix typos and unclear explanations
- Add examples and tutorials

### 🎨 UI/UX Improvements
- Follow Material Design 3 guidelines
- Maintain consistency with existing design
- Consider accessibility
- Test on different screen sizes

### 🔧 Performance & Code Quality
- Optimize slow operations
- Reduce memory usage
- Improve code organization
- Fix linting issues

## 🛠️ Development Guidelines

### Code Style
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### Flutter Best Practices
- Use `const` constructors where possible
- Implement proper state management
- Handle loading and error states
- Follow widget composition patterns

### Git Workflow
```bash
# 1. Create feature branch
git checkout -b feature/amazing-feature

# 2. Make your changes
# ... code, test, repeat ...

# 3. Commit with clear messages
git commit -m "Add user profile customization feature

- Allow users to upload custom avatars
- Add bio and favorite games sections
- Implement privacy settings for profiles
- Update user model and database schema"

# 4. Push to your fork
git push origin feature/amazing-feature

# 5. Create Pull Request on GitHub
```

### Commit Message Format
```
Type: Brief description (50 chars max)

Detailed explanation of what and why:
- What changes were made
- Why they were necessary
- Any breaking changes
- Related issue numbers (#123)
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## 🧪 Testing

### Before Submitting
- [ ] App builds without errors (`flutter build apk`)
- [ ] No new linting issues (`flutter analyze`)
- [ ] Test on both Android and iOS if possible
- [ ] Verify existing features still work
- [ ] Test edge cases and error scenarios

### Manual Testing Checklist
- [ ] Authentication flow works
- [ ] Game search and discovery
- [ ] Library management
- [ ] Rating and review system
- [ ] Profile customization
- [ ] Offline functionality

## 📝 Pull Request Process

### Before Creating PR
1. **Sync with main branch**
   ```bash
   git checkout main
   git pull upstream main
   git checkout feature/your-feature
   git rebase main
   ```

2. **Test thoroughly**
3. **Update documentation**
4. **Check for conflicts**

### PR Description Template
```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Tested on Android
- [ ] Tested on iOS
- [ ] Added/updated tests
- [ ] Verified existing functionality

## Screenshots (if applicable)
Add screenshots or GIFs showing the changes.

## Related Issues
Closes #123
```

### Review Process
1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Testing** on different devices
4. **Approval** and merge

## 🌟 Recognition

Contributors are recognized in:
- GitHub contributors list
- App's About section
- Release notes for significant contributions
- Special mentions for outstanding work

## 🤝 Community Guidelines

### Be Respectful
- Use inclusive language
- Be constructive in feedback
- Help newcomers learn
- Celebrate others' contributions

### Communication
- **Issues**: For bug reports and feature requests
- **Discussions**: For questions and ideas
- **Pull Requests**: For code contributions
- **Discord/Slack**: For real-time chat (if available)

## 📚 Resources

### Learning Flutter
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Widget Catalog](https://flutter.dev/docs/development/ui/widgets)

### GameLog Architecture
- Check existing code patterns
- Review service layer organization
- Understand state management approach
- Study Firebase integration

### Design Resources
- [Material Design 3](https://m3.material.io/)
- [Flutter Design Patterns](https://flutter.dev/docs/development/ui/layout)

## ❓ Getting Help

### Stuck? Here's how to get help:

1. **Check existing issues** and documentation
2. **Search discussions** for similar questions
3. **Create a new issue** with detailed information
4. **Join community chat** for real-time help

### When Asking for Help
- Provide clear problem description
- Include relevant code snippets
- Share error messages
- Mention your environment (OS, Flutter version, etc.)

## 🎉 Thank You!

Every contribution, no matter how small, makes GameLog better for the entire gaming community. Whether you're fixing a typo, adding a feature, or helping other contributors, you're making a difference!

**Happy coding, and welcome to the GameLog community!** 🎮✨