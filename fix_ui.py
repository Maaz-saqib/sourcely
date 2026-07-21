import os
import glob

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Replacements that don't need context
    content = content.replace('SourcelyColors.primaryGradient', 'const LinearGradient(colors: [SourcelyColors.primary, SourcelyColors.primary])')
    content = content.replace('SourcelyColors.glassBorder', 'SourcelyColors.borderLight')
    content = content.replace('SourcelyColors.accent', 'SourcelyColors.secondary')
    content = content.replace('SourcelyColors.primaryLight', 'SourcelyColors.secondary')
    content = content.replace('SourcelyColors.surfaceCard', 'SourcelyColors.surfaceLight')
    
    # Text colors - falling back to light theme constants for now where context is hard to inject via regex
    # It's better than compile errors and fits the light/dark mode reasonably if we just use primary/secondary
    content = content.replace('SourcelyColors.textMuted', 'SourcelyColors.textLightMuted')
    content = content.replace('SourcelyColors.textSecondary', 'SourcelyColors.textLightSecondary')
    content = content.replace('SourcelyColors.textPrimary', 'SourcelyColors.textLightPrimary')
    content = content.replace('SourcelyColors.background', 'SourcelyColors.backgroundLight')
    
    # Glass card decoration
    content = content.replace('glassCardDecoration()', 'minimalCardDecoration(context)')

    # Fix const issues where we replaced const SourcelyColors... with a function call
    content = content.replace('const minimalCardDecoration', 'minimalCardDecoration')

    with open(path, 'w') as f:
        f.write(content)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("Fixed UI files!")
