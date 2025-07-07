# Truely Distribution

## Installation Instructions

1. **Extract the distribution package** to your desired location
2. **Copy the config file**: 
   - Copy `config_template.py` to `config.py`
   - Edit `config.py` with your actual Zoom meeting URL and settings
3. **Run the application**:
   - Double-click `Truely.app` to start the application
   - Or right-click and select "Open" if macOS blocks the app

## Configuration

Edit `config.py` to customize:
- **ZOOM_URL**: Your Zoom meeting URL
- **APPS**: List of applications to monitor
- **START_KEY/END_KEY**: Monitoring keys
- **CHAT_MONITORING_ENABLED**: Enable/disable chat monitoring
- **STATUS_UPDATE_INTERVAL**: How often to send status updates

## Troubleshooting

If macOS blocks the app:
1. Go to System Preferences > Security & Privacy
2. Click "Open Anyway" for Truely.app

If the app doesn't start:
1. Make sure `config.py` is in the same directory as `Truely.app`
2. Check that your Zoom URL is valid
3. Ensure you have an internet connection

## Support

For issues or questions, please refer to the main documentation.
