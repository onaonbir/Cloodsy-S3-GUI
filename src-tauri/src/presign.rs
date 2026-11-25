//! AWS Signature V4 query-string presigning (what `aws s3 presign` does),
//! computed locally from a bucket access key. The secret never leaves the
//! machine; the server checks the signature like any S3 client request.

use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

const UNRESERVED: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~";

/// RFC 3986 encoding as SigV4 wants it (`/` kept only for paths).
pub fn aws_encode(s: &str, keep_slash: bool) -> String {
    let mut out = String::with_capacity(s.len());
    for &b in s.as_bytes() {
        if UNRESERVED.contains(&b) || (keep_slash && b == b'/') {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

fn hmac(key: &[u8], data: &str) -> Vec<u8> {
    let mut m = Hmac::<Sha256>::new_from_slice(key).expect("any key length");
    m.update(data.as_bytes());
    m.finalize().into_bytes().to_vec()
}

pub struct Presign<'a> {
    /// Scheme, host, optional port and the path (decoded), e.g.
    /// `http://mini:9000/bucket/a b.txt` as parts.
    pub scheme: &'a str,
    pub host: &'a str,
    pub port: Option<u16>,
    /// Decoded path segments (bucket, then the key's segments).
    pub segments: Vec<String>,
    pub access_key: &'a str,
    pub secret_key: &'a str,
    pub region: &'a str,
    pub method: &'a str,
    pub expires_secs: u64,
    /// Unix seconds.
    pub now: i64,
    pub extra_query: Vec<(String, String)>,
}

/// Presigns a request and answers the full URL.
pub fn presign(p: &Presign) -> String {
    let t = time::OffsetDateTime::from_unix_timestamp(p.now).unwrap_or(time::OffsetDateTime::UNIX_EPOCH);
    let date = format!("{:04}{:02}{:02}", t.year(), t.month() as u8, t.day());
    let amz_date = format!("{date}T{:02}{:02}{:02}Z", t.hour(), t.minute(), t.second());
    let scope = format!("{date}/{}/s3/aws4_request", p.region);

    let default_port = matches!((p.scheme, p.port), ("https", Some(443)) | ("http", Some(80)));
    let host = match p.port {
        Some(port) if !default_port => format!("{}:{port}", p.host),
        _ => p.host.to_string(),
    };

    let mut params: Vec<(String, String)> = vec![
        ("X-Amz-Algorithm".into(), "AWS4-HMAC-SHA256".into()),
        ("X-Amz-Credential".into(), format!("{}/{scope}", p.access_key)),
        ("X-Amz-Date".into(), amz_date.clone()),
        ("X-Amz-Expires".into(), p.expires_secs.to_string()),
        ("X-Amz-SignedHeaders".into(), "host".into()),
    ];
    params.extend(p.extra_query.iter().cloned());
    params.sort_by(|a, b| a.0.cmp(&b.0));
    let canonical_query =
        params.iter().map(|(k, v)| format!("{}={}", aws_encode(k, false), aws_encode(v, false))).collect::<Vec<_>>().join("&");
    let canonical_path = format!("/{}", p.segments.iter().map(|s| aws_encode(s, false)).collect::<Vec<_>>().join("/"));

    let canonical_request =
        [p.method, &canonical_path, &canonical_query, &format!("host:{host}\n"), "host", "UNSIGNED-PAYLOAD"].join("\n");
    let string_to_sign =
        ["AWS4-HMAC-SHA256", &amz_date, &scope, &hex::encode(Sha256::digest(canonical_request.as_bytes()))].join("\n");

    let k_date = hmac(format!("AWS4{}", p.secret_key).as_bytes(), &date);
    let k_region = hmac(&k_date, p.region);
    let k_service = hmac(&k_region, "s3");
    let k_signing = hmac(&k_service, "aws4_request");
    let signature = hex::encode(hmac(&k_signing, &string_to_sign));

    format!("{}://{host}{canonical_path}?{canonical_query}&X-Amz-Signature={signature}", p.scheme)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The presigned GET example from the AWS SigV4 documentation.
    #[test]
    fn matches_the_aws_example() {
        let url = presign(&Presign {
            scheme: "https",
            host: "examplebucket.s3.amazonaws.com",
            port: None,
            segments: vec!["test.txt".into()],
            access_key: "AKIAIOSFODNN7EXAMPLE",
            secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1",
            method: "GET",
            expires_secs: 86400,
            now: 1_369_353_600, // 2013-05-24T00:00:00Z
            extra_query: vec![],
        });
        assert!(url.ends_with("X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"), "{url}");
        assert!(url.starts_with("https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request"));
    }

    #[test]
    fn path_style_keeps_port_and_encodes_segments() {
        let url = presign(&Presign {
            scheme: "http",
            host: "mini",
            port: Some(9000),
            segments: vec!["bucket".into(), "a b".into(), "ç.txt".into()],
            access_key: "AK",
            secret_key: "SK",
            region: "us-east-1",
            method: "GET",
            expires_secs: 900,
            now: 1_700_000_000,
            extra_query: vec![("w".into(), "320".into())],
        });
        assert!(url.starts_with("http://mini:9000/bucket/a%20b/%C3%A7.txt?"), "{url}");
        assert!(url.contains("&w=320&") || url.contains("&w=320"), "{url}");
        let default = presign(&Presign { port: Some(80), ..Presign { scheme: "http", host: "h", port: None, segments: vec!["b".into()], access_key: "A", secret_key: "S", region: "us-east-1", method: "GET", expires_secs: 60, now: 0, extra_query: vec![] } });
        assert!(default.starts_with("http://h/b?"));
    }
}
