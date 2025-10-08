# Backend Coordination Required for Video Features

## Overview
The new UI redesign is complete, but several critical video-related features require backend implementation to function properly. Currently, these features show placeholder messages like "Time not available → Click to open clip" and "Video clip feature coming soon."

## Critical Backend Requirements

### 1. Video Timestamp Extraction API
**Status**: MANDATORY for analysis page relevance
**Current Issue**: `extract_timestamp()` helper returns "Time not available"

**Requirements**:
- Extract accurate timestamps during video processing
- Store timestamp data in `frameReference` field for each issue
- Format: Support both range timestamps (e.g., "00:02:15-00:02:30") and single timestamps
- Return format: Consistent time format (HH:MM:SS or MM:SS)

**Implementation Points**:
- Update video processing pipeline to capture timestamps when issues are detected
- Ensure `issue["frameReference"]` contains actionable timestamp data
- Modify `app/helpers/video_audits_helper.rb:extract_timestamp()` if needed

### 2. Video Screenshot/Frame Capture API
**Status**: HIGH PRIORITY for visual evidence
**Current Issue**: Only placeholder 📸 icons are shown

**Requirements**:
- Capture screenshots at issue timestamps during analysis
- Store frame images for each detected issue
- Generate thumbnails for quick preview
- Serve images via secure URLs

**Implementation Points**:
- Extract frames at specific timestamps during video processing
- Store in appropriate file storage (S3, local, etc.)
- Update `issue["thumbnail"]` and related evidence fields
- Ensure `has_evidence?()` helper can detect real evidence

### 3. Video Player Integration
**Status**: REQUIRED for user workflow validation
**Current Issue**: `openVideoClip()` shows toast message "Video clip feature coming soon"

**Requirements**:
- API endpoint to serve video segments or full video with timestamp navigation
- Support for playing video from specific timestamps
- Video player that can accept timestamp parameters
- Secure video access (authentication/authorization)

**Implementation Points**:
- Endpoint: `/video_audits/:id/video_player?timestamp=MM:SS`
- Consider video streaming vs. full download
- Implement video player controls with timestamp jumping
- Update `openVideoClip()` JavaScript function

### 4. Enhanced Video Processing Pipeline
**Requirements**:
- Process videos to extract multiple frames per issue
- Implement frame analysis for better issue detection accuracy
- Store frame reference data with precise timing information
- Generate frame metadata for frontend consumption

## Frontend Impact Areas

### Currently Working (No Backend Required)
- ✅ Dashboard summary with visual severity charts
- ✅ Issue prioritization (Critical/Important/Minor)
- ✅ Progressive disclosure and collapsible sections
- ✅ Mobile-responsive design
- ✅ Issue filtering and search
- ✅ Export functionality (PDF/CSV/JSON)
- ✅ Jira integration triggers

### Blocked Until Backend Implementation
- ❌ Video timestamp navigation ("Click to open clip")
- ❌ Visual evidence display (frame screenshots)
- ❌ Video replay for issue validation
- ❌ Accurate timestamp display in issue cards

## API Contract Suggestions

### 1. Video Timestamps
```ruby
# In VideoAudit model
issue["frameReference"] = "00:02:15-00:02:30"  # Range format
issue["timestamp"] = "00:02:15"                 # Single timestamp
```

### 2. Frame Capture
```ruby
# In issue data structure
issue["screenshots"] = [
  {
    "url" => "/uploads/frames/audit_123_frame_001.jpg",
    "timestamp" => "00:02:15",
    "type" => "issue_evidence"
  }
]
```

### 3. Video Player Endpoint
```
GET /video_audits/:id/player?timestamp=00:02:15
Returns: Video player interface or JSON with video URL + timestamp
```

## Priority Ranking

1. **🔴 CRITICAL**: Video timestamp extraction - Required for basic functionality
2. **🟡 HIGH**: Frame capture/screenshots - Essential for evidence-based analysis
3. **🔵 MEDIUM**: Video player integration - Important for workflow validation

## Testing Requirements

Once backend features are implemented:
- Verify timestamp accuracy against actual video content
- Test video player functionality across browsers
- Validate frame capture quality and relevance
- Ensure mobile video playback works properly

## Next Steps

1. **Backend Team**: Implement video timestamp extraction first
2. **Backend Team**: Add frame capture during video processing
3. **Frontend Team**: Update `openVideoClip()` function once video API is ready
4. **QA Team**: Test complete workflow with real video evidence

---

**Note**: The current UI redesign provides a much better user experience for text-based analysis, but the video features are essential for the platform's core value proposition of video-based UX auditing.