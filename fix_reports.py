import os
os.chdir("C:\\Users\\user\\famhub_app")

with open('lib/features/farm_management/presentation/pages/reports_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the getActivityReport call
old1 = '''    // Fetch activity report with hierarchy filters
    final activityReport = await repository.getActivityReport(
      farmId: farmId,
      fieldId: hierarchy.fieldId,
      cropOrLivestockId: hierarchy.cropOrLivestockId,
      cropOrLivestockType: hierarchy.cropOrLivestockType,
    );'''

new1 = '''    // Fetch activity report — hierarchy filtering is client-side
    final activityReport = await repository.getActivityReport(
      farmId: farmId,
    );'''

content = content.replace(old1, new1)

# Replace the getProductionReport call
old2 = '''    // Fetch production report
    final productionReport = await repository.getProductionReport(
      farmId: farmId,
      fieldId: hierarchy.fieldId,
      cropOrLivestockId: hierarchy.cropOrLivestockId,
    );'''

new2 = '''    // Fetch production report — hierarchy filtering is client-side
    final productionReport = await repository.getProductionReport(
      farmId: farmId,
    );'''

content = content.replace(old2, new2)

with open('lib/features/farm_management/presentation/pages/reports_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')