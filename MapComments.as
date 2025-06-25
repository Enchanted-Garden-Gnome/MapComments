string mapId;
string MXURL;
array<MapComment@> m_comments;
bool m_commentsStopRequest = false;
bool m_commentsError = false;
bool showComments = false;
int trackId;
bool in_game = false;


void Main() {
    MXURL = "trackmania.exchange";
}


void Update(float dt) {
    auto playground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (playground is null) {
        mapId = "";
        in_game = false;
        return;
    }

    if (playground.Map.IdName != mapId) {
        mapId = playground.Map.IdName;
        in_game = true;
        StartMXCommentsRequest();
    }

}

Net::HttpRequest@ Get(const string &in url)
{
    auto ret = Net::HttpRequest();
    ret.Method = Net::HttpMethod::Get;
    ret.Url = url;
    ret.Start();
    return ret;
}

void CheckMXCommentsRequest()
{
    // if (!MX::APIDown && !m_commentsStopRequest && !m_commentsError && m_MXCommentsRequest is null && UI::IsWindowAppearing()) {
    if (                !m_commentsStopRequest && !m_commentsError && m_MXCommentsRequest is null && UI::IsWindowAppearing()) {
        StartMXCommentsRequest();
    }

    if (m_MXCommentsRequest !is null && m_MXCommentsRequest.Finished()) {
        string res = m_MXCommentsRequest.String();
        int resCode = m_MXCommentsRequest.ResponseCode();
        auto json = m_MXCommentsRequest.Json();
        @m_MXCommentsRequest = null;

        print("MapTab::CheckRequest (Comments): " + res);

        if (resCode >= 400 || json.GetType() == Json::Type::Null || !json.HasKey("Results")) {
            print("MapTab::CheckRequest (Comments): Error parsing response");
            m_commentsError = true;
            return;
        }

        // Handle the response
        Json::Value@ mapComments = json["Results"];

        for (uint i = 0; i < mapComments.Length; i++) {
            MapComment@ comment = MapComment(mapComments[i]);
            m_comments.InsertLast(comment);
        }

        m_commentsStopRequest = true;
    }
}


Net::HttpRequest@ m_MXCommentsRequest;

void StartMXCommentsRequest() {
    string url = "https://trackmania.exchange/api/tracks/get_track_info/uid/" + mapId;
    Net::HttpRequest@ r = Get(url);
    while (r !is null && !r.Finished()){
        
    }
    auto json = r.Json();
    trackId = json["TrackID"];
    url = "https://"+MXURL+"/api/maps/comments?trackId=" + trackId + "&count=50&fields=";
    print("MapTab::StartRequest (Comments): " + url);
    @m_MXCommentsRequest = Get(url);
}

void Render() {
    if (!showComments) {
        return;
    }

    if (!in_game) {
        UI::SetNextWindowSize(400, 200, UI::Cond::Appearing);
        if (UI::Begin("Comments", showComments)) { 
            UI::Text("Must be in a track to show comments");
        }
        UI::End();
        return;
    }

    RenderMapComments();

}

void RenderMenu() {
    if (UI::MenuItem(Icons::StackExchange + " Map Comments")) {
        showComments = !showComments;
    }
}

void RenderMapComments() {
    UI::SetNextWindowSize(400, 200, UI::Cond::Appearing);
    if (UI::Begin("Comments", showComments)) {
        UI::BeginChild("MapMXCommentsChild");

        CheckMXCommentsRequest();

        if (m_MXCommentsRequest !is null && !m_MXCommentsRequest.Finished()) {
            int HourGlassValue = Time::Stamp % 3;
            string Hourglass = (HourGlassValue == 0 ? Icons::HourglassStart : (HourGlassValue == 1 ? Icons::HourglassHalf : Icons::HourglassEnd));
            UI::Text(Hourglass + " Loading...");
        } else if (m_commentsError) {
            UI::AlignTextToFramePadding();
            UI::Text("\\$f00" + Icons::Times + "\\$z Error while loading comments");
        } else {
            if (UI::Button(Icons::Plus + " Post comment")) OpenBrowserURL("https://"+MXURL+"/commentupdate/"+trackId);

            UI::SameLine();

            if (UI::Button(Icons::Refresh)) {
                m_comments.RemoveRange(0, m_comments.Length);
                m_commentsStopRequest = false;
                StartMXCommentsRequest();
            }

            if (m_comments.Length == 0) {
                UI::AlignTextToFramePadding();
                UI::Text("No comments found for this map. Be the first!");
            } else {
                UI::DrawList@ dl = UI::GetWindowDrawList();

                for (uint i = 0; i < m_comments.Length; i++) {
                    MapComment@ comment = m_comments[i];

                    RenderComment(comment);

                    vec2 pos = UI::GetCursorScreenPos();

                    UI::Indent();

                    for (uint r = 0; r < comment.Replies.Length; r++) {
                        RenderComment(comment.Replies[r]);

                        vec4 rect = UI::GetItemRect();
                        float middle = rect.y + Draw::MeasureString(comment.Username).y;

                        dl.AddLine(vec2(pos.x, middle), vec2(pos.x + 15, middle), vec4(0.5, 0.5, 0.5, 1), 5.0f);

                        if (r == comment.Replies.Length - 1) {
                            dl.AddLine(pos, vec2(pos.x, middle), vec4(0.5, 0.5, 0.5, 1), 7.0f);
                        }
                    }

                    UI::Unindent();
                }
            }
        }
    }
    UI::EndChild();
    UI::End();
}


const int regexFlags = Regex::Flags::ECMAScript | Regex::Flags::CaseInsensitive;
string MXText(const string &in comment)
{
    if (comment.Length == 0) {
        return comment;
    }

    string formatted = "";

    formatted =
        comment.Replace("[tmx]", "Trackmania\\$075Exchange\\$z")
            .Replace("[mx]", "Mania\\$09FExchange\\$z")
            .Replace("[i]", "*")
            .Replace("[/i]", "*")
            .Replace("[u]", "__")
            .Replace("[/u]", "__")
            .Replace("[s]", "~~")
            .Replace("[/s]", "~~")
            .Replace("[hr]", "")
            .Replace("[list]", "\n")
            .Replace("[/list]", "\n")
            .Replace("&nbsp;", " ")
            .Replace("\r", "  ");

    // bold text replacement
    formatted = Regex::Replace(formatted, "\\[b\\] *?(.*?) *?\\[\\/b\\]", "**$1**", regexFlags);

    // automatic links. See https://daringfireball.net/projects/markdown/syntax#autolink
    formatted = Regex::Replace(formatted, "(https?:\\/\\/(?:www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&//=]*))", "<$1>", regexFlags);

    // url regex replacement: https://regex101.com/r/UcN0NN/1
    formatted = Regex::Replace(formatted, "\\[url=([^\\]]*)\\]([^\\[]*)\\[\\/url\\]", "[$2]($1)", regexFlags);

    // img replacement: https://regex101.com/r/WafxU9/1
    formatted = Regex::Replace(formatted, "\\[img\\]([^\\[]*)\\[\\/img\\]", "( Image: $1 )", regexFlags);

    // item replacement: https://regex101.com/r/c9LwXn/1
    formatted = Regex::Replace(formatted, "\\[item\\]([^\\r^\\n]*)", "- $1", regexFlags);

    // quote replacement: https://regex101.com/r/kuI7TO/1
    formatted = Regex::Replace(formatted, "\\[quote\\]([^\\[]*)\\[\\/quote\\]", "> $1", regexFlags);

    // youtube replacement
    formatted = Regex::Replace(formatted, "\\[youtube\\]([^\\[]*)\\[\\/youtube\\]", "[Youtube video]($1)", regexFlags);

    // user replacement
    formatted = Regex::Replace(formatted, "\\[user\\]([^\\[]*)\\[\\/user\\]", "( User ID: $1 )", regexFlags);

    // track replacement
    formatted = Regex::Replace(formatted, "\\[track\\]([^\\[]*)\\[\\/track\\]", "( Track ID: $1 )", regexFlags);
    formatted = Regex::Replace(formatted, "\\[track=([^\\]]*)\\]([^\\[]*)\\[\\/track\\]", "( Track ID: $2 )", regexFlags);

    // align replacement
    formatted = Regex::Replace(formatted, "\\[align=([^\\]]*)\\]([^\\[]*)\\[\\/align\\]", "$2", regexFlags);

    Regex::SearchAllResult@ results = Regex::SearchAll(formatted, "[(:](\\w+)[):]");

    for (uint r = 0; r < results.Length; r++) {
        string[] result = results[r]; // TODO remove when the new OP version is released
        string match = result[0];
        string shortname = result[1];

        // if (MX::Icons.Exists(shortname)) {
        //     formatted = formatted.Replace(match, string(MX::Icons[shortname]));
        // }
    }

    return formatted;
}

class MapComment {
    int Id;
    int UserId;
    string Username;
    string Comment;
    int UpdatedAt;
    bool HasAwarded;
    bool IsAuthor;
    int PostedAt;
    int ReplyTo;
    array<MapComment@> Replies;

    MapComment(const Json::Value &in json)
    {
        try {
            Id = json["CommentId"];
            UserId = json["User"]["UserId"];
            Username = json["User"]["Name"];
            Comment = MXText(json["Comment"]);
            if (json["UpdatedAt"].GetType() != Json::Type::Null) UpdatedAt = Time::ParseFormatString('%FT%T', json["UpdatedAt"]);
            HasAwarded = json["HasAwarded"];
            IsAuthor = json["IsAuthor"];
            PostedAt = Time::ParseFormatString('%FT%T', json["PostedAt"]);
            if (json.HasKey("ReplyTo")) ReplyTo = json["ReplyTo"];

            if (json.HasKey("Replies")) {
                for (uint i = 0; i < json["Replies"].Length; i++) {
                    try {
                        Replies.InsertLast(MapComment(json["Replies"][i]));
                    } catch {
                        print("Error parsing reply for comment " + Id + ": " + getExceptionInfo());
                    }
                }
            }
        } catch {
            print("Error parsing comment info for the map: " + getExceptionInfo());
        }
    }
}

void RenderComment(MapComment@ comment) {

    UI::PushStyleColor(UI::Col::Border, vec4(1));
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 5.0);

    UI::BeginChild("MapComment"+comment.Id, vec2(UI::GetContentRegionAvail().x, 0), UI::ChildFlags::Border | UI::ChildFlags::AutoResizeY);

    UI::Text(comment.Username);
    UI::SetItemTooltip("Click to view " + comment.Username + "'s profile");
    // if (UI::IsItemClicked()) mxMenu.AddTab(UserTab(comment.UserId), true);

    if (comment.HasAwarded) {
        UI::SameLine();
        UI::Text("· \\$FD0" + Icons::Trophy);
        UI::SetItemTooltip("User has awarded this map");
    }

    if (comment.IsAuthor) {
        UI::SameLine();
        UI::Text("· " + Icons::Wrench);
        UI::SetItemTooltip("User is a map author");
    }

    UI::SameLine();
    vec2 cursor = UI::GetCursorPos();
    vec2 region = UI::GetContentRegionAvail();
    string timeFormatted = Time::FormatString("%d %b %Y at %R", comment.PostedAt);
    UI::SetCursorPos(cursor + vec2(region.x - Draw::MeasureString(timeFormatted).x, 0));
    UI::Text(timeFormatted);

    UI::Separator();

    UI::Markdown(comment.Comment);

    UI::EndChild();
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}