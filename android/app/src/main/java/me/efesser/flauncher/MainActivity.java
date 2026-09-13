/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package me.efesser.flauncher;

import android.Manifest;
import android.app.ActivityManager;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.Context;
import android.content.Intent;
import android.content.pm.*;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Size;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Pair;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletionService;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorCompletionService;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class MainActivity extends FlutterActivity
{
    private final String METHOD_CHANNEL = "me.efesser.flauncher/method";
    private final String APPS_EVENT_CHANNEL = "me.efesser.flauncher/event_apps";
    private final String NETWORK_EVENT_CHANNEL = "me.efesser.flauncher/event_network";

    private static final int REQUEST_CODE_PICK_IMAGE = 4201;

    private MethodChannel.Result _pendingPickImageResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine)
    {
        super.configureFlutterEngine(flutterEngine);

        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();

        new MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method)
            {
                case "getApplications" -> result.success(getApplications());
                case "getApplicationBanner" -> result.success(getApplicationBanner(call.arguments()));
                case "getApplicationIcon" -> result.success(getApplicationIcon(call.arguments()));
                case "applicationExists" -> result.success(applicationExists(call.arguments()));
                case "launchActivityFromAction" -> result.success(launchActivityFromAction(call.arguments()));
                case "launchApp" -> result.success(launchApp(call.arguments()));
                case "openSettings" -> result.success(openSettings());
                case "openAppInfo" -> result.success(openAppInfo(call.arguments()));
                case "uninstallApp" -> result.success(uninstallApp(call.arguments()));
                case "isDefaultLauncher" -> result.success(isDefaultLauncher());
                case "installApk" -> result.success(installApk(call.arguments()));
                case "canInstallPackages" -> result.success(canInstallPackages());
                case "openUnknownSourcesSettings" -> result.success(openUnknownSourcesSettings());
                case "checkForGetContentAvailability" -> result.success(checkForGetContentAvailability());
                case "pickImageBytes" -> pickImageBytes(result);
                case "requestImageLibraryAccess" -> requestImageLibraryAccess(result);
                case "getGalleryImages" -> getGalleryImages(result);
                case "getGalleryImageBytes" -> getGalleryImageBytes(result, call.arguments());
                case "startAmbientMode" -> result.success(startAmbientMode());
                case "getActiveNetworkInformation" -> result.success(getActiveNetworkInformation());
                case "getSupportedAbis" -> result.success(Arrays.asList(Build.SUPPORTED_ABIS));
                case "getMemoryInfo" -> result.success(getMemoryInfo());
                case "cleanMemory" -> new Thread(() -> runOnUiThread(() -> result.success(cleanMemory()))).start();
                default -> throw new IllegalArgumentException();
            }
        });

        new EventChannel(messenger, APPS_EVENT_CHANNEL).setStreamHandler(
                new LauncherAppsEventStreamHandler(this));

        new EventChannel(messenger, NETWORK_EVENT_CHANNEL).setStreamHandler(
                new NetworkEventStreamHandler(this));
    }

    private List<Map<String, Serializable>> getApplications() {
        ExecutorService executor = Executors.newFixedThreadPool(4);
        CompletionService<Pair<Boolean, List<ResolveInfo>>> queryIntentActivitiesCompletionService =
                new ExecutorCompletionService<>(executor);
        queryIntentActivitiesCompletionService.submit(() ->
                Pair.create(false, queryIntentActivities(false)));
        queryIntentActivitiesCompletionService.submit(() ->
                Pair.create(true, queryIntentActivities(true)));
        List<ResolveInfo> tvActivitiesInfo = null;
        List<ResolveInfo> nonTvActivitiesInfo = null;

        int completed = 0;
        while (completed < 2) {
            try {
                var activitiesInfo = queryIntentActivitiesCompletionService.take().get();

                if (!activitiesInfo.first) {
                    tvActivitiesInfo = activitiesInfo.second;
                }
                else {
                    nonTvActivitiesInfo = activitiesInfo.second;
                }
            } catch (InterruptedException | ExecutionException ignored) { }
            finally {
                completed += 1;
            }
        }

        CompletionService<Map<String, Serializable>> completionService = new ExecutorCompletionService<>(executor);

        List<Map<String, Serializable>> applications = new ArrayList<>(
                tvActivitiesInfo.size() + nonTvActivitiesInfo.size());

        boolean settingsPresent = false;
        int appCount = 0;
        for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
            if (!settingsPresent) {
                settingsPresent = tvActivityInfo.activityInfo.packageName.equals("com.android.tv.settings");
            }

            completionService.submit(() -> buildAppMap(tvActivityInfo.activityInfo, false, null));
            appCount += 1;
        }

        for (ResolveInfo nonTvActivityInfo : nonTvActivitiesInfo) {
            boolean nonDuplicate = true;

            if (!settingsPresent) {
                settingsPresent = nonTvActivityInfo.activityInfo.packageName.equals("com.android.settings");
            }

            for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
                if (tvActivityInfo.activityInfo.packageName.equals(nonTvActivityInfo.activityInfo.packageName)) {
                    nonDuplicate = false;
                    break;
                }
            }

            if (nonDuplicate) {
                appCount += 1;
                completionService.submit(() -> buildAppMap(nonTvActivityInfo.activityInfo, true, null));
            }
        }

        while (appCount > 0) {
            try {
                Future<Map<String, Serializable>> appMap = completionService.take();
                applications.add(appMap.get());
            } catch (InterruptedException | ExecutionException ignored) {
            } finally {
                appCount -= 1;
            }
        }

        executor.shutdown();

        if (!settingsPresent) {
            PackageManager packageManager = getPackageManager();
            Intent settingsIntent = new Intent(Settings.ACTION_SETTINGS);
            ActivityInfo activityInfo = settingsIntent.resolveActivityInfo(packageManager, 0);

            if (activityInfo != null) {
                applications.add(buildAppMap(activityInfo, false, Settings.ACTION_SETTINGS));
            }
        }

        return applications;
    }

    public Map<String, Serializable> getApplication(String packageName) {
        Map<String, Serializable> map = Map.of();
        PackageManager packageManager = getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);

        if (intent == null) {
            intent = packageManager.getLaunchIntentForPackage(packageName);
        }

        if (intent != null) {
            ActivityInfo activityInfo = intent.resolveActivityInfo(getPackageManager(), 0);

            if (activityInfo != null) {
                map = buildAppMap(activityInfo, false, null);
            }
        }

        return map;
    }

    private byte[] getApplicationBanner(String packageName) {
        byte[] imageBytes = new byte[0];

        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadBanner(packageManager);

            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable);
            }
        } catch (PackageManager.NameNotFoundException ignored) { }

        return imageBytes;
    }

    private byte[] getApplicationIcon(String packageName) {
        byte[] imageBytes = new byte[0];

        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadIcon(packageManager);

            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable);
            }
        } catch (PackageManager.NameNotFoundException ignored) { }

        return imageBytes;
    }

    private boolean applicationExists(String packageName) {
        int flags;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            flags = PackageManager.MATCH_UNINSTALLED_PACKAGES;
        } else {
            flags = PackageManager.GET_UNINSTALLED_PACKAGES;
        }

        try {
            getPackageManager().getApplicationInfo(packageName, flags);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }

    private List<ResolveInfo> queryIntentActivities(boolean sideloaded) {
        String category;
        if (sideloaded) {
            category = Intent.CATEGORY_LAUNCHER;
        }
        else {
            category = Intent.CATEGORY_LEANBACK_LAUNCHER;
        }

        // NOTE: Would be nice to query the applications that match *either* of the above categories
        // but from the addCategory function documentation, it says that it will "use activities
        // that provide *all* the requested categories"
        Intent intent = new Intent(Intent.ACTION_MAIN)
                .addCategory(category);

        return getPackageManager()
                .queryIntentActivities(intent, 0);
    }

    private Map<String, Serializable> buildAppMap(ActivityInfo activityInfo, boolean sideloaded, String action) {
        PackageManager packageManager = getPackageManager();

        String  applicationName = activityInfo.loadLabel(packageManager).toString(),
                applicationVersionName = "";
        try {
            applicationVersionName = packageManager.getPackageInfo(activityInfo.packageName, 0).versionName;
        }
        catch (PackageManager.NameNotFoundException ignored) { }

        Map<String, Serializable> appMap = new HashMap<>();
        appMap.put("name", applicationName);
        appMap.put("packageName", activityInfo.packageName);
        appMap.put("version", applicationVersionName);
        appMap.put("sideloaded", sideloaded);

        if (action != null) {
            appMap.put("action", action);
        }
        return appMap;
    }

    private boolean launchActivityFromAction(String action) {
        return tryStartActivity(new Intent(action));
    }

    private boolean launchApp(String packageName) {
        PackageManager packageManager = getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);

        if (intent == null) {
            intent = packageManager.getLaunchIntentForPackage(packageName);
        }

        return tryStartActivity(intent);
    }

    private boolean openSettings() {
        return launchActivityFromAction(Settings.ACTION_SETTINGS);
    }

    private boolean openAppInfo(String packageName) {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null));

        return tryStartActivity(intent);
    }

    private boolean uninstallApp(String packageName) {
        Intent intent = new Intent(Intent.ACTION_DELETE)
                .setData(Uri.fromParts("package", packageName, null));

        return tryStartActivity(intent);
    }

    private boolean installApk(String path) {
        File file = new File(path);

        if (!file.exists()) {
            return false;
        }

        Uri uri = FileProvider.getUriForFile(this, getPackageName() + ".fileprovider", file);
        Intent intent = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);

        return tryStartActivity(intent);
    }

    private boolean canInstallPackages() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return getPackageManager().canRequestPackageInstalls();
        }

        return true;
    }

    private boolean openUnknownSourcesSettings() {
        Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                .setData(Uri.fromParts("package", getPackageName(), null));

        return tryStartActivity(intent);
    }

    private boolean checkForGetContentAvailability() {
        List<ResolveInfo> intentActivities = getPackageManager().queryIntentActivities(
                new Intent(Intent.ACTION_GET_CONTENT, null).setTypeAndNormalize("image/*"),
                0);

        return !intentActivities.isEmpty();
    }

    // 选壁纸用 ACTION_GET_CONTENT(DocumentsUI)而不是 image_picker:image_picker 在
    // Android 11+ 优先走系统 Photo Picker,不少电视盒子的 Photo Picker 对遥控器
    // D-pad 无响应(无焦点、方向键和返回键都失效)。DocumentsUI 支持 D-pad 导航。
    // 成功时把选中图片的原始字节回给 Dart;取消或失败回 null。
    private void pickImageBytes(MethodChannel.Result result) {
        if (_pendingPickImageResult != null) {
            // 上一次选图还没回来,忽略新请求,避免旧的 Result 被顶掉后永远悬空。
            result.success(null);
            return;
        }

        Intent intent = new Intent(Intent.ACTION_GET_CONTENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setTypeAndNormalize("image/*");

        try {
            _pendingPickImageResult = result;
            startActivityForResult(intent, REQUEST_CODE_PICK_IMAGE);
        }
        catch (Exception ignored) {
            _pendingPickImageResult = null;
            result.success(null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data)
    {
        if (requestCode != REQUEST_CODE_PICK_IMAGE) {
            super.onActivityResult(requestCode, resultCode, data);
            return;
        }

        MethodChannel.Result result = _pendingPickImageResult;
        _pendingPickImageResult = null;

        if (result == null) {
            return;
        }

        byte[] bytes = null;

        if (resultCode == RESULT_OK && data != null && data.getData() != null) {
            try (InputStream inputStream = getContentResolver().openInputStream(data.getData())) {
                ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = inputStream.read(buffer)) != -1) {
                    outputStream.write(buffer, 0, read);
                }
                bytes = outputStream.toByteArray();
            }
            catch (IOException | SecurityException ignored) {
                bytes = null;
            }
        }

        result.success(bytes);
    }

    // ---- 应用内相册选图 --------------------------------------------------
    // 系统 Photo Picker 和 DocumentsUI 在不少电视盒子上对遥控器 D-pad 无响应,
    // 所以选壁纸改走应用内相册浏览器:读 MediaStore 的图片缩略图网格给 Flutter
    // 渲染(焦点遍历用 launcher 自己的逻辑),选中后再读原图字节。

    private static final int REQUEST_CODE_IMAGE_PERMISSION = 4202;

    private MethodChannel.Result _pendingImagePermissionResult;

    private String imageReadPermission() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                ? Manifest.permission.READ_MEDIA_IMAGES
                : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    private boolean hasImageLibraryPermission() {
        // Android 6.0 之前没有运行时权限,安装时即授予。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true;
        }

        return checkSelfPermission(imageReadPermission()) == PackageManager.PERMISSION_GRANTED;
    }

    // 返回 true 表示已有(或刚被用户授予)相册读权限;拒绝时 Dart 端回落 DocumentsUI。
    private void requestImageLibraryAccess(MethodChannel.Result result) {
        if (hasImageLibraryPermission()) {
            result.success(true);
            return;
        }

        _pendingImagePermissionResult = result;
        requestPermissions(new String[]{imageReadPermission()}, REQUEST_CODE_IMAGE_PERMISSION);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults)
    {
        if (requestCode == REQUEST_CODE_IMAGE_PERMISSION) {
            MethodChannel.Result result = _pendingImagePermissionResult;
            _pendingImagePermissionResult = null;

            if (result != null) {
                result.success(grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED);
            }
            return;
        }

        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    // 返回最新的至多 200 张图,每张 {id, thumb(JPEG 字节,≤320px)}。后台线程执行。
    private void getGalleryImages(MethodChannel.Result result) {
        new Thread(() -> {
            List<Map<String, Object>> images = new ArrayList<>();

            try {
                if (!hasImageLibraryPermission()) {
                    result.success(images);
                    return;
                }

                ContentResolver contentResolver = getContentResolver();
                try (Cursor cursor = contentResolver.query(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        new String[]{MediaStore.Images.Media._ID},
                        null,
                        null,
                        MediaStore.Images.Media.DATE_ADDED + " DESC")) {
                    int count = 0;
                    while (cursor != null && cursor.moveToNext() && count < 200) {
                        long id = cursor.getLong(0);
                        Uri uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id);
                        Bitmap thumbnail = loadThumbnail(contentResolver, id, uri);

                        if (thumbnail == null) {
                            continue;
                        }

                        ByteArrayOutputStream stream = new ByteArrayOutputStream();
                        thumbnail.compress(Bitmap.CompressFormat.JPEG, 80, stream);

                        Map<String, Object> map = new HashMap<>();
                        map.put("id", id);
                        map.put("thumb", stream.toByteArray());
                        images.add(map);
                        count++;
                    }
                }
            }
            catch (Exception ignored) {
            }

            runOnUiThread(() -> result.success(images));
        }).start();
    }

    private Bitmap loadThumbnail(ContentResolver contentResolver, long id, Uri uri) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                return contentResolver.loadThumbnail(uri, new Size(320, 320), null);
            }
            return MediaStore.Images.Thumbnails
                    .getThumbnail(contentResolver, id, MediaStore.Images.Thumbnails.MINI_KIND, null);
        }
        catch (Exception ignored) {
            return null;
        }
    }

    // 按相册条目 id 读原图原始字节;失败或用户未授权时回 null。
    private void getGalleryImageBytes(MethodChannel.Result result, Object arguments) {
        new Thread(() -> {
            byte[] bytes = null;

            try {
                long id = ((Number) arguments).longValue();
                Uri uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id);

                try (InputStream inputStream = getContentResolver().openInputStream(uri)) {
                    ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
                    byte[] buffer = new byte[64 * 1024];
                    int read;
                    while ((read = inputStream.read(buffer)) != -1) {
                        outputStream.write(buffer, 0, read);
                    }
                    bytes = outputStream.toByteArray();
                }
            }
            catch (Exception ignored) {
                bytes = null;
            }

            runOnUiThread(() -> result.success(bytes));
        }).start();
    }

    private boolean isDefaultLauncher() {
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        ResolveInfo defaultLauncher = getPackageManager().resolveActivity(intent, 0);

        if (defaultLauncher != null && defaultLauncher.activityInfo != null) {
            return defaultLauncher.activityInfo.packageName.equals(getPackageName());
        }

        return false;
    }

    private boolean startAmbientMode()
    {
        Intent intent = new Intent(Intent.ACTION_MAIN)
                .setClassName("com.android.systemui", "com.android.systemui.Somnambulator");

        return tryStartActivity(intent);
    }

    private Map<String, Object> getActiveNetworkInformation()
    {
        ConnectivityManager connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetwork());
        }
        else {
            //noinspection deprecation
            return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetworkInfo());
        }
    }

    private Map<String, Object> getMemoryInfo()
    {
        ActivityManager.MemoryInfo memoryInfo = getMemoryInfoInternal();
        return memoryMap(memoryInfo.totalMem, memoryInfo.availMem);
    }

    private Map<String, Object> cleanMemory()
    {
        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        long availableBefore = getMemoryInfoInternal().availMem;

        Set<String> skipPackages = new HashSet<>(Arrays.asList(
                getPackageName(),
                "android",
                "com.android.systemui",
                "com.android.settings",
                "com.android.tv.settings"));

        Set<String> packages = new HashSet<>();
        for (List<ResolveInfo> activitiesInfo : Arrays.asList(queryIntentActivities(false), queryIntentActivities(true))) {
            for (ResolveInfo activityInfo : activitiesInfo) {
                packages.add(activityInfo.activityInfo.packageName);
            }
        }

        PackageManager packageManager = getPackageManager();
        for (String packageName : packages) {
            if (skipPackages.contains(packageName)) {
                continue;
            }

            // NOTE: Only kill third-party apps. Killing system apps is pointless: the system
            // restarts them right away, so no memory is actually freed.
            try {
                ApplicationInfo applicationInfo = packageManager.getApplicationInfo(packageName, 0);

                if ((applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0) {
                    continue;
                }
            } catch (PackageManager.NameNotFoundException ignored) {
                continue;
            }

            // NOTE: On Android 14+ the system silently ignores this call for other apps' processes
            // (platform behavior change, independent of targetSdk). The reported freed memory stays
            // honest in either case, since it is measured before and after.
            activityManager.killBackgroundProcesses(packageName);
        }

        // Give the system a moment to actually reclaim the memory of the killed processes.
        try {
            Thread.sleep(500);
        } catch (InterruptedException ignored) {
        }

        long availableAfter = getMemoryInfoInternal().availMem;

        Map<String, Object> map = new HashMap<>();
        map.put("freed", Math.max(0, availableAfter - availableBefore));
        map.put("avail", availableAfter);
        return map;
    }

    private ActivityManager.MemoryInfo getMemoryInfoInternal()
    {
        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(memoryInfo);
        return memoryInfo;
    }

    private Map<String, Object> memoryMap(long total, long avail)
    {
        Map<String, Object> map = new HashMap<>();
        map.put("total", total);
        map.put("avail", avail);
        return map;
    }

    private boolean tryStartActivity(Intent intent)
    {
        boolean success = true;

        try {
            startActivity(intent);
        }
        catch (Exception ignored) {
            success = false;
        }

        return success;
    }

    private byte[] drawableToByteArray(Drawable drawable) {
        if (drawable.getIntrinsicWidth() <= 0 || drawable.getIntrinsicHeight() <= 0) {
            return new byte[0];
        }

        Bitmap bitmap;
        if (drawable instanceof BitmapDrawable bitmapDrawable) {
            bitmap = bitmapDrawable.getBitmap();
        }
        else {
            bitmap = drawableToBitmap(drawable);
        }
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
        return stream.toByteArray();
    }

    Bitmap drawableToBitmap(Drawable drawable) {
        Bitmap bitmap = Bitmap.createBitmap(
                drawable.getIntrinsicWidth(),
                drawable.getIntrinsicHeight(),
                Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }
}
